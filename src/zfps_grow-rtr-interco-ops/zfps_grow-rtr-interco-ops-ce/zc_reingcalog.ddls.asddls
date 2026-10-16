//----------------------------------------------------------------------
// Modified by    : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Change ID      : V001 (CC)
// Date           : 08.07.2026
// Description    : App CA - Motor de Calculo IC - F3.1 Fundamentos RAP (DD-B6)
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'CA - Log de Eventos (Drill-down)'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZC_ReingCALog
  as projection on ZI_ReingCALog
{
  key CalcRunId,
  key LineNum,
  key LogNum,
      Action,
      StatusFrom,
      StatusTo,
      CreatedBy,
      CreatedAt,
      Message,
      GroupRunId,
      _Line : redirected to parent ZC_ReingCALine,
      //Begin Insert V001 (CC) - DD-B6
      _Run : redirected to ZC_ReingCARun
      //End Insert V001 (CC) - DD-B6
}
