acc_results_18 <- readRDS("./data/output/3_olofsson/2018/acc_results.rds")
acc_results_20 <- readRDS("./data/output/3_olofsson/2020/acc_results.rds")
acc_results_22 <- readRDS("./data/output/3_olofsson/2022/acc_results.rds")


tbl <- tibble::as_tibble(
    acc_results_18$accuracy[c("user", "producer")]
)
tbl$label <- names(acc_results_18$accuracy$user)
tbl <- tbl[tbl$label %in% c("Forest", "Deforestation_Mask", "Water"),]
tbl$year <- "2018"
