#!/bin/bash

# Get the current folder name
current_dir=$(pwd)
folder_name=$(basename "$current_dir")

# Define the destination path for the mirror folder
mirror_folder="/mnt/d/OneDrive - Kasvi/Farmacogenética/Resultados e Documentos pacientes/Dados brutos rotina NGS/$folder_name"

# Create the mirror folder
mkdir -p "$mirror_folder"

# Copy all .xlsx files to the mirror folder
cp *.xlsx "$mirror_folder"

echo "Copy files to mirror folder completed."
