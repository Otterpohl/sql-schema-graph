from loguru import logger
from pathlib import Path
import sql_functions


if __name__ == "__main__":
    LogPath = str(Path(__file__).resolve().parent) + "\\log\\file_{time}.log"
    logger.add(LogPath, level='DEBUG')

    sql_functions.main()

    logger.info("Completed Successfully")
