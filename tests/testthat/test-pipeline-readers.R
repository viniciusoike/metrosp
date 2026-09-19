test_that("monthly passenger readers preserve the published system total", {
  pipeline_dir <- test_path("..", "..", "data-raw", "R")
  skip_if_not(dir.exists(pipeline_dir), "data-raw pipeline code not available")

  env <- new.env(parent = globalenv())
  suppressWarnings(sys.source(file.path(pipeline_dir, "build", "dims.R"), env))
  suppressWarnings(sys.source(file.path(pipeline_dir, "helpers.R"), env))
  suppressWarnings(
    sys.source(file.path(pipeline_dir, "import", "import_historic.R"), env)
  )

  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      "DEMANDA;Linha 1 - Azul;Rede",
      "Total;100;100",
      "Media dos Dias Uteis;10;10",
      "Media dos Sabados;8;8",
      "Media dos Domingos;6;6",
      "Maxima Diaria;12;12"
    ),
    path
  )

  result <- env$clean_psg_month(env$read_psg_month(path))

  expect_setequal(result$line_number, c(1L, 99L))
})

test_that("unrecognized line labels fail visibly", {
  pipeline_dir <- test_path("..", "..", "data-raw", "R")
  skip_if_not(dir.exists(pipeline_dir), "data-raw pipeline code not available")

  env <- new.env(parent = globalenv())
  suppressWarnings(sys.source(file.path(pipeline_dir, "helpers.R"), env))

  expect_snapshot(
    error = TRUE,
    env$label_line_number(c("Linha 1 - Azul", "unknown"))
  )
})
