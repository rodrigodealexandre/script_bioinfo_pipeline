import os
import pandas as pd
import re

def extract_sample_label(file_name):
    sample_label = ""
    file_name = os.path.basename(file_name)
    match = re.search(r"POOL-1(\d+)", file_name)
    if match:
        sample_label = match.group()
    return sample_label

folder_path = os.getcwd()  # Use current working directory as the default folder

data = []  # List to store the dataframes from each file
column_names = None  # Placeholder for the column names

for root, dirs, files in os.walk(folder_path):
    for file_name in files:
        if file_name.endswith("hg38_multianno.xlsx"):
            file_path = os.path.join(root, file_name)
            df = pd.read_excel(file_path, header=0)
            df.insert(0, "Sample label", extract_sample_label(file_path))
            data.append(df)
            if column_names is None:
                column_names = df.columns

if data:
    final_df = pd.concat(data, ignore_index=True)
    final_df = final_df.reindex(columns=column_names)
    final_df.to_excel("merged_file.xlsx", index=False)
    print("Excel files merged successfully.")
else:
    print("No Excel files found matching the criteria.")
