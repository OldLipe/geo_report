library(sits)

set.seed(123)

years_to_analyse <- c("2018", "2020", "2022")

lapply(years_to_analyse, function(year) {
    #
    # Classified map
    #
    class_dir <- paste0("./data/raw/1_classifications/1_raw/", year)
    class_cube <- sits_cube(
        source = "BDC",
        collection = "LANDSAT-OLI-16D",
        bands = "class",
        data_dir = class_dir,
        labels = c("1" = "Clear_Cut_Bare_Soil", "2" = "Clear_Cut_Burned_Area",
                   "3" = "Mountainside_Forest", "4" = "Forest",
                   "5" = "Riparian_Forest", "6" = "Clear_Cut_Vegetation",
                   "7" = "Water", "8" = "Wetland", "9" = "Seasonally_Flooded")
    )

    #
    # TerraClass map
    #
    tc_dir <- paste0("./data/raw/4_TC_amazon/", year)
    tc_cube <- sits_cube(
        source = "BDC",
        collection = "LANDSAT-OLI-16D",
        bands = "class",
        data_dir = tc_dir,
        labels = c("1" = "VEGETACAO NATURAL FLORESTAL PRIMARIA",
                   "2" = "VEGETACAO NATURAL FLORESTAL SECUNDARIA",
                   "9" = "SILVICULTURA",
                   "10" = "PASTAGEM ARBUSTIVA/ARBOREA",
                   "11" = "PASTAGEM HERBACEA",
                   "12" = "CULTURA AGRICOLA PERENE",
                   "13" = "CULTURA AGRICOLA SEMIPERENE",
                   "14" = "CULTURA AGRICOLA TEMPORARIA DE 1 CICLO",
                   "15" = "CULTURA AGRICOLA TEMPORARIA DE MAIS DE 1 CICLO",
                   "16" = "MINERACAO",
                   "17" = "URBANIZADA",
                   "20" = "OUTROS USOS",
                   "22" = "DESFLORESTAMENTO NO ANO",
                   "23" = "CORPO DAGUA",
                   "25" = "NAO OBSERVADO",
                   "51" = "NATURAL NAO FLORESTAL")
    )

    #
    # Masked map
    #
    masked_dir <- paste0("./data/output/1_masks/", year)
    sits_reclassify(
        cube = class_cube,
        mask = tc_cube,
        rules = list(
            "Natural_Non_Forested" = mask == "NATURAL NAO FLORESTAL"
        ),
        memsize = 10,
        multicores = 10,
        version = "masked-nf",
        output_dir = masked_dir
    )
})
