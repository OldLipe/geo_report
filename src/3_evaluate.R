library(tibble)
library(dplyr)
library(tidyr)
library(sits)
library(ggplot2)
library(cowplot)

set.seed(123)

years_to_analyse <- c("2018", "2020", "2022")

res_years <- lapply(years_to_analyse, function(year) {
    olofssons_dir <- "./data/output/3_olofsson/"

    res_paths <- list.files(paste0(olofssons_dir, year), full.names = TRUE)

    res_lst <- lapply(seq_along(res_paths), function(i) {
        res_path <- res_paths[[i]]
        acc_results <- readRDS(res_path)

        tbl <- tibble::as_tibble(acc_results$byClass)
        cols_sel <- c("Sensitivity", "Specificity",
                      "Pos Pred Value", "Neg Pred Value",
                      "F1")
        tbl <- tbl[, cols_sel]

        colnames(tbl) <- c(
            "producer", "specificity", "user", "neg_pred", "F1_score"
        )
        tbl$label <- gsub(
            pattern = "Class: ",
            replacement = "",
            x = row.names(acc_results$byClass)
        )

        tbl <- tbl[tbl$label %in% c("Forest", "Deforestation_Mask", "Water"),]
        tbl$year <- year
        tbl$idx <- i
        tbl$acc <- acc_results$overall[["Accuracy"]]
        tbl
    })
    do.call(rbind, res_lst)
})

#
# Binding results in row level
#
res_tbl <- do.call(rbind, res_years)


#
# Getting mean and std from tbl
#
res_stats <- res_tbl |>
    dplyr::group_by(.data[["year"]]) |>
    dplyr::summarise(mean = mean(acc), std = sd(acc))

#
# Accuracy plot
#
plot_lst <- lapply(years_to_analyse, function(year) {
    res_analyses <- res_tbl |>
        dplyr::select(dplyr::all_of(c("producer", "user", "label", "year",
                                      "idx", "acc"))) |>
        dplyr::group_by(.data[["year"]], .data[["label"]]) |>
        dplyr::summarise(user_mean = mean(user), user_sd = sd(user),
                         producer_mean = mean(producer), producer_sd = sd(producer)) |>
        dplyr::filter(year == !!year)


    res_test_sts <- res_analyses |>
        tidyr::pivot_longer(
            cols = dplyr::starts_with(c("user_mean", "producer_mean")),
            names_to = "mean_labels",
            values_to = "mean_values") |>
        dplyr::mutate(
            mean_labels = dplyr::case_when(
                mean_labels == "user_mean" ~ "User",
                mean_labels == "producer_mean" ~ "Producer"
            )
        ) |>
        dplyr::mutate(
            label = dplyr::case_when(
                label == "Deforestation_Mask" ~ "Deforestation",
                label == "Forest" ~ "Forest",
                label == "Water" ~ "Water"
            )
        )

    ggplot2::ggplot(res_test_sts) +
        ggplot2::geom_bar(
            ggplot2::aes(x = label, y = mean_values, fill =  mean_labels),
            position = "dodge",
            stat = "identity",
            width = 0.5
        ) +
        ggplot2::geom_errorbar(
            ggplot2::aes(x = label,
                         ymin = mean_values - user_sd,
                         ymax = mean_values + user_sd),
            width = 0.1, colour = "orange", linewidth = 0.3) +
        ggplot2::scale_y_continuous(limits = c(0,1), breaks = seq(0, 1, 0.1), expand = c(0, 0)) +
        cowplot::theme_minimal_hgrid(16) +
        ggplot2::theme( legend.position = "top") +
        ggplot2::geom_text(
            ggplot2::aes(x = label, y = mean_values, label = round(mean_values, digits = 2), group = mean_labels),
            position = ggplot2::position_dodge(width = 0.60),
            stat = "identity", vjust = -0.25) +
        ggplot2::scale_fill_manual(values = c("#4A91C2", "#DE8146")) +
        ggplot2::labs(x = "Classes", y = "Accuracy concordance", fill = "")
})

cowplot::plot_grid(
    cowplot::plot_grid(plot_lst[[1]], plot_lst[[2]], nrow = 1, ncol = 2, label_size = 11,
                       labels = c("(a) 2018", "(b) 2020"), label_x = -0.025),
    cowplot::plot_grid(NULL, plot_lst[[3]], NULL, nrow = 1, rel_widths = c(0.5, 1, 0.5), label_size = 11,
                       labels = "(c) 2022", label_x = 0.95),
    nrow = 2
)

ggplot2::ggsave(
    filename = "./data/output/4_plots/acc.png",
    plot = ggplot2::last_plot(),
    device = "png",
    width = 11.01,
    height = 9.38,
    units = "in"
)

#### Kfold ####
samples <- readRDS("./data/raw/3_global_samples/samples.rds")
kfold <- sits::sits_kfold_validate(
    samples,
    folds = 5,
    ml_method = sits::sits_rfor(),
    multicores = 10
)
saveRDS(kfold, "./data/output/6_kfold/kfold_res.rds")

#### Model plot ####
rfor_model <- readRDS("./data/raw/2_global_model/rfor_model.rds")
plot(rfor_model)
ggplot2::ggsave(
    filename = "./data/output/5_plots/rfor.png",
    plot = ggplot2::last_plot(),
    device = "png"
)
