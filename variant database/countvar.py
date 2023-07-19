import pandas as pd

# Read the merged file
df = pd.read_excel("merged_file.xlsx")

# Filter out rows with "." in HGVS column
df = df[df["HGVS"] != "."]

# Group by HGVS and calculate statistics
grouped = df.groupby("HGVS").agg({
    "AF_UMI": ["count", "mean", "max"],
    "Sample label": lambda x: ";".join([f"{sample} ({af:.2f})" for sample, af in zip(x, df.loc[x.index, "AF_UMI"])]),
    "gnomAD3.1": "first",
    "avsnp150": "first",
    "CLNSIG": "first",
    "ExonicFunc_refGeneWithVer": "first"
})

# Flatten the multi-level column names
grouped.columns = ["_".join(col).rstrip("_") for col in grouped.columns.values]

# Rename the count column
grouped.rename(columns={"AF_UMI_count": "Occurrences"}, inplace=True)

# Add the first column with unique HGVS values
grouped.reset_index(inplace=True)

# Save the result to a new Excel file
grouped.to_excel("processed_file.xlsx", index=False)
