#!/usr/bin/env Rscript
#' Synchronize Google Drive Manuscript with Local Tables and Figures
#'
#' This script downloads the live Google Doc manuscript, injects publication-grade
#' APA tables and figures in-place using OpenXML DOM manipulation, and uploads
#' the updated document back to Google Drive without altering the author formatting.

library(googledrive)

doc_id <- "1vXW0PsCeXUghrCbfIylU-RjzpjQOK1uqrZ03NNMnb7k"
live_docx <- "draft_live.docx"
updated_docx <- "draft_updated.docx"

message("[1/4] Ensuring table summaries in cache/ are up to date...")
source("Scripts/generate_md_tables.R")

message("[2/4] Downloading live manuscript from Google Drive...")
drive_auth(email = "omarlizardo@gmail.com")
drive_download(as_id(doc_id), path = live_docx, overwrite = TRUE)

message("[3/4] Performing in-place XML injection of tables and figures...")
exit_code <- system2("python3", args = c("Scripts/sync_manuscript.py", live_docx, updated_docx))
if (exit_code != 0) {
  stop("Error during in-place XML injection.")
}

message("[4/4] Uploading updated manuscript back to Google Drive...")
drive_update(as_id(doc_id), media = updated_docx)

# Clean up local temporary files
if (file.exists(live_docx)) unlink(live_docx)
if (file.exists(updated_docx)) unlink(updated_docx)
if (file.exists("draft_live_test.docx")) unlink("draft_live_test.docx")
if (file.exists("draft_updated_test.docx")) unlink("draft_updated_test.docx")

message("Synchronization complete! Google Doc updated successfully.")
