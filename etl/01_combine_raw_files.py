import pandas as pd
from pathlib import Path
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

# Define paths
project_root = Path(__file__).parent.parent
raw_data_path = project_root / "raw_data"
staging_path = project_root / "staging"

# Expected columns in the combined dataframe
EXPECTED_COLUMNS = [
    "ServiceStationName",
    "Address",
    "Suburb",
    "Postcode",
    "Brand",
    "FuelCode",
    "PriceUpdatedDate",
    "Price"
]


def main():

    # Ensure staging folder exists
    staging_path.mkdir(parents=True, exist_ok=True)

    dataframes = []
    load_dt = datetime.now()

    # Read all files in raw_data folder and load them into dataframes
    for file in raw_data_path.glob("*.*"):
        try:
            if file.suffix.lower() == ".xlsx":
                df = pd.read_excel(file)
            elif file.suffix.lower() == ".csv":
                df = pd.read_csv(file)
            else:
                logger.warning(f"Skipping unsupported file type: {file.name}")
                continue
            
            # Check for expected columns
            missing_cols = [col for col in EXPECTED_COLUMNS if col not in df.columns]
            if missing_cols:
                logger.warning(f"{file.name} is missing columns: {missing_cols}. Skipping this file.")
                continue

            df = df[EXPECTED_COLUMNS].copy()  # Ensure we only keep expected columns

            # Standardise types
            df["Price"] = pd.to_numeric(df["Price"], errors="coerce")
            df["PriceUpdatedDate"] = pd.to_datetime(df["PriceUpdatedDate"], errors="coerce")
            df["Postcode"] = df["Postcode"].astype(str).str.zfill(4)  # Ensure postcode is a string with leading zeros

            # Add metadata columns
            df["SourceFile"] = file.name
            df["LoadDate"] = load_dt
            
            dataframes.append(df)
            logger.info(f"Loaded: {file.name}")
        except Exception as e:
            logger.error(f"Error loading {file.name}: {e}")

    # Combine all dataframes
    if dataframes:
        combined_df = pd.concat(dataframes, ignore_index=True)
        
        # Save to staging folder as csv
        output_path = staging_path / "combined_data.csv"
        combined_df.to_csv(output_path, index=False)
        logger.info(f"Successfully combined {len(dataframes)} files into: {output_path}")
    else:
        logger.warning("No valid files were loaded.")


if __name__ == "__main__":
    main()