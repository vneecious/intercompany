// ----------------------------------------------------------------------
// Created by     : Carlos (CC)
// Requirement N° : ME-17 (Delta v2 PRGI)
// Date           : 29.07.2026
// Description    : Static RAP upload action parameter
// Transport      : DS4K9B5VNA
// Reference      : 5000047741
// ----------------------------------------------------------------------
@EndUserText.label: 'ME upload parameter'
define abstract entity ZI_ReingMEUploadParam
{
  PeriodYear  : abap.numc(4);
  PeriodMonth : abap.numc(2);
  FileContent : abap.string(0);
  FileName    : abap.string(0);
}
