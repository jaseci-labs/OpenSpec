import from "node:process" { default as process }

glob:priv unicode: bool = process.platform != "win32"
              or bool(process.env["WT_SESSION"])
              or bool(process.env["TERM_PROGRAM"]),
          CELLS: dict[str, str] = {
              ".": "  ",
              "F": "██" if unicode else "##",
              "D": "░░" if unicode else "++",
          },
          BLANK: str = "........",
          SHAPES: list[tuple[str, str, str]] = [
              (BLANK, BLANK, BLANK),
              (BLANK, BLANK, "....DD.."),
              (BLANK, BLANK, "....FF.."),
              ("....DD..", BLANK, "....FF.."),
              ("....FF..", "...D..D.", "....FF.."),
              ("....FF..", "...F..F.", "..D.FF.D"),
              ("....FF..", "...F..F.", "..F.FF.F"),
              ("....FF..", "...F..F.", "..F.FF.F"),
          ];

glob WELCOME_ANIMATION: any = rec(
    interval=120,
    frames=[
        [
            "".join([CELLS[c] for c in row])
            for row in [BLANK, BLANK, BLANK, tip, ring, bar, bar, bar, ring, tip]
        ]
        for (tip, ring, bar) in SHAPES
    ],
);
