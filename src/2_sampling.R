library(sits)

set.seed(123)

years_to_analyse <- c("2018", "2020", "2022")
n_iter <- 10

res <- lapply(years_to_analyse, function(year) {

    class_dir <- paste0("./data/output/1_masks/", year)
    class_cube <- sits_cube(
        source = "BDC",
        collection = "LANDSAT-OLI-16D",
        bands = "class",
        data_dir = class_dir,
        labels = c("1" = "Clear_Cut_Bare_Soil", "2" = "Clear_Cut_Burned_Area",
                   "3" = "Mountainside_Forest", "4" = "Forest",
                   "5" = "Riparian_Forest", "6" = "Clear_Cut_Vegetation",
                   "7" = "Water_Bodies", "8" = "Water_Bodies",
                   "9" = "Water_Bodies", "10" = "Natural_Non_Forested"),
        version = "masked-nf"
    )

    tc_dir <- paste0("./data/raw/4_TC_amazon/", year)
    tc_cube <- sits_cube(
        source = "BDC",
        collection = "LANDSAT-OLI-16D",
        bands = "class",
        data_dir = tc_dir,
        labels = c("1" = "Forest",
                   "2" = "Forest",
                   "9" = "Deforestation_Mask",
                   "10" = "Deforestation_Mask",
                   "11" = "Deforestation_Mask",
                   "12" = "Deforestation_Mask",
                   "13" = "Deforestation_Mask",
                   "14" = "Deforestation_Mask",
                   "15" = "Deforestation_Mask",
                   "16" = "Deforestation_Mask",
                   "17" = "Deforestation_Mask",
                   "20" = "Deforestation_Mask",
                   "22" = "Deforestation_Mask",
                   "23" = "Water",
                   "25" = "NAO OBSERVADO",
                   "51" = "NATURAL NAO FLORESTAL")
    )
    lapply(seq_len(n_iter), function(n_i) {
        #
        # Sampling design
        #
        ro_sampling_design <- sits_sampling_design(
            cube = class_cube,
            expected_ua = c(
                "Clear_Cut_Bare_Soil" = 0.75,
                "Clear_Cut_Burned_Area" = 0.70,
                "Mountainside_Forest" = 0.70,
                "Forest" = 0.75,
                "Riparian_Forest" = 0.70,
                "Clear_Cut_Vegetation" = 0.70,
                "Water_Bodies" = 0.70
            ),
            alloc_options = c(120, 100),
            std_err = 0.01,
            rare_class_prop = 0.1
        )
        ro_sampling_design <- ro_sampling_design[, 1:6 ]

        #
        # Extracting validation samples
        #
        sampling_dir <- paste0(
            "./data/output/2_validation/", year,
            "/samples_validation_", n_i, ".shp"
        )
        samples_validation <- sits_stratified_sampling(
            cube = class_cube,
            sampling_design = ro_sampling_design,
            alloc = "alloc_120",
            multicores = 1,
            shp_file = sampling_dir
        )

        #
        # Extracting samples validation values
        #
        samples_validation <- terra::extract(
            terra::rast(tc_cube$file_info[[1]]$path),
            terra::vect(samples_validation),
            bind = TRUE, xy = TRUE
        )
        samples_tbl <- tibble::as_tibble(samples_validation)
        colnames(samples_tbl) <- c("predicted", "reference", "x", "y")

        #
        # Removing non-observed points
        #
        samples_tbl <- samples_tbl |> dplyr::filter(
            reference != 25
        )

        #
        # relabeling reference
        #
        samples_tbl <- samples_tbl |>
            dplyr::mutate(
                reference = dplyr::case_when(
                    reference %in% c(1, 2)  ~ "Forest",
                    reference %in% c(9, 10, 11, 12, 13, 14, 15, 16, 17, 20, 22) ~ "Deforestation_Mask",
                    reference == 23 ~ "Water"
                )
            )

        #
        # relabeling predicted
        #
        samples_tbl <- samples_tbl |>
            dplyr::mutate(
                predicted = dplyr::case_when(
                    predicted %in% c("Clear_Cut_Bare_Soil", "Clear_Cut_Burned_Area", "Clear_Cut_Vegetation") ~ "Deforestation_Mask",
                    predicted %in% c("Mountainside_Forest", "Forest", "Riparian_Forest") ~ "Forest",
                    predicted %in% c("Water_Bodies") ~ "Water"
                )
            )

        #
        # Relabeling forest as water
        #
        samples_tbl <- samples_tbl |>
            dplyr::mutate(
                reference = dplyr::case_when(
                    predicted == "Water" & reference == "Forest" ~ "Water",
                    .default = as.character(reference)
                )
            )

        #
        # Getting accuracy
        #
        acc <- sits:::.accuracy_pixel_assess(
            cube = tc_cube,
            pred = samples_tbl[["predicted"]],
            ref = samples_tbl[["reference"]]
        )

        acc_dir <- paste0(
            "./data/output/3_olofsson/", year, "/acc_results_", n_i,".rds"
        )
        saveRDS(acc, acc_dir)
    })
})
