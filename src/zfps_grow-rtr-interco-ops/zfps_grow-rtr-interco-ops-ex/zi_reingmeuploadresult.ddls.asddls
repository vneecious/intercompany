// ----------------------------------------------------------------------
// Created by     : Carlos (CC)
// Requirement N° : ME-17 (Delta v2 PRGI)
// Date           : 29.07.2026
// Description    : Static RAP upload action row result
// Transport      : DS4K9B5VNA
// Reference      : 5000047741
// ----------------------------------------------------------------------
@EndUserText.label: 'ME upload result'
define abstract entity ZI_ReingMEUploadResult
{
  RowNumber : abap.int4;
  Severity  : abap.char(1);
  Message   : abap.char(255);
}
