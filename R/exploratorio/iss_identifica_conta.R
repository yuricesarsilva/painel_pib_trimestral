# Identifica contas de ISS no MSC MSCC de Boa Vista e extrai valor realizado
library(httr2)
library(dplyr)

# Boa Vista jan/2023
resp <- request("https://apidatalake.tesouro.gov.br/ords/siconfi/tt/msc_orcamentaria") |>
  req_url_query(
    id_ente        = 1400100,
    an_referencia  = 2023,
    me_referencia  = 1,
    co_tipo_matriz = "MSCC",
    classe_conta   = 6,
    id_tv          = "period_change"
  ) |>
  req_timeout(30) |>
  req_error(is_error = function(r) FALSE) |>
  req_perform()

df <- resp |> resp_body_json(simplifyVector = TRUE) |> (\(x) as.data.frame(x$items))()
cat("Total de linhas:", nrow(df), "\n")

# --- 1. Contas contábeis únicas -------------------------------------
cat("\nContas contábeis únicas (primeiros 6 dígitos):\n")
df$cc6 <- substr(df$conta_contabil, 1, 6)
print(sort(unique(df$cc6)))

# --- 2. Naturezas de receita únicas ---------------------------------
cat("\nNaturezas de receita únicas:\n")
print(sort(unique(df$natureza_receita)))

# --- 3. Filtra ISS (natureza 1112xxxx) --------------------------------
# 1112 = ISSQN na tabela de natureza de receita do Siconfi/MF
iss <- df |>
  filter(grepl("^1112", natureza_receita)) |>
  filter(natureza_conta == "C")   # crédito = receita realizada positiva

cat("\n--- ISS (natureza_receita 1112xxxx) ---\n")
cat("Linhas:", nrow(iss), "\n")
if (nrow(iss) > 0) {
  resumo <- iss |>
    group_by(conta_contabil, natureza_receita, natureza_conta) |>
    summarise(valor_total = sum(valor, na.rm=TRUE), .groups="drop") |>
    arrange(desc(valor_total))
  print(resumo)
  cat(sprintf("TOTAL ISS jan/2023 Boa Vista: R$ %.2f\n", sum(iss$valor)))
}

# --- 4. Filtra conta contábil 6211 (ISS) ----------------------------
# A conta 621100000 parece ser o ISS municipal
iss_cc <- df |>
  filter(grepl("^6211", conta_contabil)) |>
  filter(natureza_conta == "C")

cat("\n--- Conta contábil 6211x ---\n")
cat("Linhas:", nrow(iss_cc), "\n")
if (nrow(iss_cc) > 0) {
  resumo_cc <- iss_cc |>
    group_by(conta_contabil, natureza_receita, natureza_conta) |>
    summarise(valor_total = sum(valor, na.rm=TRUE), .groups="drop") |>
    arrange(desc(valor_total))
  print(resumo_cc)
  cat(sprintf("TOTAL via conta 6211x: R$ %.2f\n", sum(iss_cc$valor)))
}

# --- 5. Compara com conta 621200000 (usada no ICMS estado) ----------
# 621200000 é ICMS; para ISS seria 621100000 ou diferente?
cat("\n--- Contas 6212x (ICMS) ---\n")
icms_cc <- df[grepl("^6212", df$conta_contabil), ]
cat("Linhas:", nrow(icms_cc), "\n")
if (nrow(icms_cc) > 0) print(unique(icms_cc[, c("conta_contabil","natureza_receita")]))
