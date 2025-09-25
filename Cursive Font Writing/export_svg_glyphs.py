#!/usr/bin/env python3
"""Export each glyph in a font as an individual SVG file."""

from __future__ import annotations

import argparse
import pathlib
import unicodedata
from typing import Dict

from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.reverseContourPen import ReverseContourPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

# Mapping for characters that cannot be represented safely in file names.
SPECIAL_FILENAMES: Dict[int, str] = {
    ord(" "): "space",
    ord("!"): "exclamation_mark",
    ord("\""): "quotation_mark",
    ord("#"): "hash",
    ord("$"): "dollar",
    ord("%"): "percent",
    ord("&"): "ampersand",
    ord("'"): "apostrophe",
    ord("("): "left_parenthesis",
    ord(")"): "right_parenthesis",
    ord("*"): "asterisk",
    ord("+"): "plus",
    ord(","): "comma",
    ord("-"): "hyphen",
    ord("."): "period",
    ord("/"): "slash",
    ord(":"): "colon",
    ord(";"): "semicolon",
    ord("<"): "less_than",
    ord("="): "equals",
    ord(">"): "greater_than",
    ord("?"): "question_mark",
    ord("@"): "at_sign",
    ord("["): "left_bracket",
    ord("\\"): "backslash",
    ord("]"): "right_bracket",
    ord("^"): "caret",
    ord("_"): "underscore",
    ord("`"): "grave",
    ord("{"): "left_brace",
    ord("|"): "vertical_bar",
    ord("}"): "right_brace",
    ord("~"): "tilde",
}


DEFAULT_STROKE_WIDTH_RATIO = 0.05


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export each mapped glyph in a font to its own SVG file.",
    )
    parser.add_argument(
        "font_path",
        help="Path to the font file to process (e.g. .otf, .ttf)",
    )
    parser.add_argument(
        "--output",
        default="../Rio/svg",
        help="Directory where SVG files will be written (default: ../Rio/svg)",
    )
    parser.add_argument(
        "--stroke-width",
        type=float,
        help="Stroke width in font units; defaults to 5% of the font's units per em.",
    )
    return parser.parse_args()


def sanitize_filename(char: str) -> str:
    codepoint = ord(char)
    if char.isalpha() and char.isupper():
        return f"Capital-{char}"
    if char.isalnum():
        return char
    if codepoint in SPECIAL_FILENAMES:
        return SPECIAL_FILENAMES[codepoint]

    unicode_name = unicodedata.name(char, "")
    if unicode_name:
        return unicode_name.lower().replace(" ", "_").replace("-", "_")
    return f"u{codepoint:04x}"


def get_vertical_metrics(font: TTFont) -> tuple[int, int, int]:
    units_per_em = font["head"].unitsPerEm

    ascent = None
    descent = None

    if "hhea" in font:
        ascent = font["hhea"].ascent
        descent = font["hhea"].descent

    if (ascent is None or descent is None) and "OS/2" in font:
        os2_table = font["OS/2"]
        ascent = ascent or os2_table.sTypoAscender
        descent = descent or os2_table.sTypoDescender

    if ascent is None or descent is None:
        ascent = units_per_em
        descent = -units_per_em // 4

    return units_per_em, ascent, descent


def _points_close(p1: tuple[float, float], p2: tuple[float, float], *, tolerance: float = 0.5) -> bool:
    return abs(p1[0] - p2[0]) <= tolerance and abs(p1[1] - p2[1]) <= tolerance


def _get_last_point(operator: str, operands: tuple) -> tuple[float, float] | None:
    if not operands:
        return None
    if operator == "qCurveTo":
        for point in reversed(operands):
            if point is not None:
                return point
        return None
    return operands[-1]


def _remove_duplicate_segments(recorded_value: list) -> list:
    """Remove duplicate segments that trace back over the same path.

    This font has contours that go forward and then backward over the same path,
    creating an outline effect. For stroke-based rendering, we only want the forward path.
    """
    result = []
    i = 0
    while i < len(recorded_value):
        operator, operands = recorded_value[i]

        # Always keep moveTo, closePath, and endPath
        if operator in ("moveTo", "closePath", "endPath"):
            result.append((operator, operands))
            i += 1
            continue

        # For drawing operations, check if there's a duplicate in reverse
        # Look ahead to see if the next operations trace back
        if i + 1 < len(recorded_value):
            # Check if we're at the midpoint of a contour that doubles back
            # This is a heuristic: if we find the same operation type with similar but reversed parameters
            # We'll keep the first half and skip the second half

            # For now, use a simple approach: keep all operations until we hit a closePath or endPath
            # Then check if the second half mirrors the first half
            result.append((operator, operands))
        else:
            result.append((operator, operands))

        i += 1

    return result


def _split_contour_at_midpoint(contour: list) -> list:
    """Split a contour that doubles back on itself, keeping only the first half."""
    if len(contour) < 3:  # moveTo + at least 2 operations
        return contour

    # Find the midpoint (excluding moveTo at start and closePath/endPath at end)
    drawing_ops = []
    move_to = None
    close_op = None

    for op, operands in contour:
        if op == "moveTo":
            move_to = (op, operands)
        elif op in ("closePath", "endPath"):
            close_op = (op, operands)
        else:
            drawing_ops.append((op, operands))

    if not drawing_ops:
        return contour

    # Take the first half of the drawing operations
    midpoint = len(drawing_ops) // 2
    first_half = drawing_ops[:midpoint]

    # Reconstruct the contour
    result = []
    if move_to:
        result.append(move_to)
    result.extend(first_half)
    # Don't add closePath for open contours

    return result


def _reverse_contour_manually(contour: list) -> list:
    """Manually reverse a contour's direction."""
    if not contour or len(contour) < 2:
        return contour

    if contour[0][0] != "moveTo":
        return contour

    # Collect all the points
    move_to_point = contour[0][1][0]
    operations = contour[1:]

    # Remove closePath/endPath if present
    if operations and operations[-1][0] in ("closePath", "endPath"):
        operations = operations[:-1]

    if not operations:
        return contour

    # Build a list of all points in order
    points = [move_to_point]
    for op, operands in operations:
        if op == "lineTo":
            points.append(operands[0])
        elif op == "curveTo":
            points.append(operands[-1])
        elif op == "qCurveTo":
            for pt in reversed(operands):
                if pt is not None:
                    points.append(pt)
                    break

    # Start from the last point
    result = [("moveTo", (points[-1],))]

    # Reverse the operations
    for i, (op, operands) in enumerate(reversed(operations)):
        # The previous point is at index -(i+2) in the points list
        prev_point = points[-(i+2)]

        if op == "lineTo":
            result.append(("lineTo", (prev_point,)))
        elif op == "curveTo":
            # Reverse cubic bezier: swap control points
            cp1, cp2, end = operands
            result.append(("curveTo", (cp2, cp1, prev_point)))
        elif op == "qCurveTo":
            # Reverse quadratic bezier
            # For qCurveTo, we need to reverse the control points
            reversed_pts = list(reversed([pt for pt in operands if pt is not None]))
            result.append(("qCurveTo", tuple(reversed_pts + [prev_point])))

    return result


def _glyph_to_svg_commands(glyph, glyph_set, ascent: int) -> str:
    # First, draw the glyph to a recording pen
    recording_pen = RecordingPen()
    glyph.draw(recording_pen)

    # Split the recording into contours and process each one BEFORE reversing
    contours = []
    current_contour = []

    for operator, operands in recording_pen.value:
        if operator == "moveTo":
            if current_contour:
                # Process the previous contour - split at midpoint
                split_contour = _split_contour_at_midpoint(current_contour)
                # Then reverse it for left-to-right drawing
                reversed_contour = _reverse_contour_manually(split_contour)
                contours.append(reversed_contour)
            current_contour = [(operator, operands)]
        else:
            current_contour.append((operator, operands))

    if current_contour:
        split_contour = _split_contour_at_midpoint(current_contour)
        reversed_contour = _reverse_contour_manually(split_contour)
        contours.append(reversed_contour)

    # Flatten the contours back into a single list
    processed_value = []
    for contour in contours:
        processed_value.extend(contour)

    svg_pen = SVGPathPen(glyph_set)
    # Convert from font coordinates (y-up) to SVG coordinates (y-down) by flipping on Y and translating by ascent
    # This produces standard SVG path data that renders correctly in typical SVG renderers and CoreGraphics
    transform_pen = TransformPen(svg_pen, (1, 0, 0, -1, 0, ascent))

    contour_start: tuple[float, float] | None = None
    last_point: tuple[float, float] | None = None
    qcurve_closed = False

    for operator, operands in processed_value:
        if operator == "moveTo":
            contour_start = operands[0]
            last_point = operands[0]
            qcurve_closed = False
            transform_pen.moveTo(*operands)
        elif operator in {"lineTo", "curveTo"}:
            getattr(transform_pen, operator)(*operands)
            maybe_point = _get_last_point(operator, operands)
            if maybe_point is not None:
                last_point = maybe_point
            qcurve_closed = False
        elif operator == "qCurveTo":
            getattr(transform_pen, operator)(*operands)
            if operands and operands[-1] is None and contour_start is not None:
                last_point = contour_start
                qcurve_closed = True
            else:
                maybe_point = _get_last_point(operator, operands)
                if maybe_point is not None:
                    last_point = maybe_point
                qcurve_closed = False
        elif operator == "closePath":
            if contour_start and last_point and (_points_close(last_point, contour_start) or qcurve_closed):
                transform_pen.closePath()
            contour_start = None
            last_point = None
            qcurve_closed = False
        elif operator == "endPath":
            contour_start = None
            last_point = None
            qcurve_closed = False
        else:
            getattr(transform_pen, operator)(*operands)
            maybe_point = _get_last_point(operator, operands)
            if maybe_point is not None:
                last_point = maybe_point
            qcurve_closed = False

    return svg_pen.getCommands()





def export_glyphs(font: TTFont, output_dir: pathlib.Path, stroke_width: float) -> None:
    glyph_set = font.getGlyphSet()
    cmap = font.getBestCmap()
    units_per_em, ascent, descent = get_vertical_metrics(font)
    vertical_extent = ascent - descent

    print(f"Font metrics: units_per_em={units_per_em}, ascent={ascent}, descent={descent}")
    print(f"Exporting to: {output_dir.resolve()}")
    print(f"Stroke width: {stroke_width}")

    exported_count = 0
    for codepoint, glyph_name in sorted(cmap.items()):
        if glyph_name not in glyph_set:
            continue

        char = chr(codepoint)
        filename = sanitize_filename(char)
        svg_path = output_dir / f"{filename}.svg"

        glyph = glyph_set[glyph_name]
        path_data = _glyph_to_svg_commands(glyph, glyph_set, ascent)

        # Skip empty glyphs
        if not path_data or path_data.strip() == "":
            print(f"Skipping empty glyph: {char} ({filename})")
            continue

        advance_width, _ = font["hmtx"].metrics.get(glyph_name, (units_per_em, 0))

        svg_content = _build_svg(
            path_data=path_data,
            advance_width=advance_width,
            vertical_extent=vertical_extent,
            ascent=ascent,
            descent=descent,
            units_per_em=units_per_em,
            stroke_width=stroke_width,
            glyph_name=glyph_name,
            codepoint=codepoint,
        )

        svg_path.write_text(svg_content, encoding="utf-8")
        exported_count += 1
        print(f"Exported: {char} -> {filename}.svg (advance: {advance_width})")

    print(f"Successfully exported {exported_count} glyphs")


def _build_svg(
    *,
    path_data: str,
    advance_width: int,
    vertical_extent: int,
    ascent: int,
    descent: int,
    units_per_em: int,
    stroke_width: float,
    glyph_name: str | None = None,
    codepoint: int | None = None,
) -> str:
    stroke_width_str = f"{stroke_width:.6f}".rstrip("0").rstrip(".")
    glyph_attr = f" data-glyph-name=\"{glyph_name}\"" if glyph_name else ""
    code_attr = f" data-codepoint=\"{codepoint}\"" if codepoint is not None else ""
    return (
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<svg xmlns=\"http://www.w3.org/2000/svg\" "
        f"width=\"{advance_width}\" height=\"{vertical_extent}\" "
        f"viewBox=\"0 0 {advance_width} {vertical_extent}\" "
        f"data-advance=\"{advance_width}\" data-ascent=\"{ascent}\" data-descent=\"{descent}\" "
        f"data-vertical-extent=\"{vertical_extent}\" data-units-per-em=\"{units_per_em}\"{glyph_attr}{code_attr} "
        "fill=\"none\" stroke=\"currentColor\" "
        f"stroke-width=\"{stroke_width_str}\" stroke-linecap=\"round\" "
        "stroke-linejoin=\"round\">\n"
        f"  <path d=\"{path_data}\"/>\n"
        "</svg>\n"
    )


def main() -> None:
    args = parse_args()
    font_path = pathlib.Path(args.font_path).expanduser().resolve()
    output_dir = pathlib.Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    with TTFont(font_path) as font:
        stroke_width = args.stroke_width
        if stroke_width is None:
            stroke_width = font["head"].unitsPerEm * DEFAULT_STROKE_WIDTH_RATIO
        elif stroke_width <= 0:
            raise ValueError("--stroke-width must be positive.")

        export_glyphs(font, output_dir, float(stroke_width))


if __name__ == "__main__":
    main()

