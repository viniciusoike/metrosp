# unrecognized line labels fail visibly

    Code
      env$label_line_number(c("Linha 1 - Azul", "unknown"))
    Condition
      Error in `env$label_line_number()`:
      ! Unrecognized line label: "unknown".
