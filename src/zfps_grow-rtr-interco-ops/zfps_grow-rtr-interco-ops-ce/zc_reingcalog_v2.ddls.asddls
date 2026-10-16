@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'CA - Log de Eventos V2'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZC_ReingCALog_V2
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
      _Line : redirected to parent ZC_ReingCALine_V2,
      _Run  : redirected to ZC_ReingCARun_V2
}
