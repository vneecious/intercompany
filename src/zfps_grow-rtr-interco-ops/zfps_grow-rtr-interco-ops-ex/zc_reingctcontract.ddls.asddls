@EndUserText.label: 'CT - Contrato IC Root Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define root view entity ZC_ReingCTContract
  provider contract transactional_query
  as projection on ZI_ReingCTContract
{
  key CtId,
      CtUuid,
      Lifnr,
      Bukrs,
      ExtContract,
      ValidFrom,
      ValidTo,
      Waers,
      Responsible,
      EmailContact,
      RenewalDays,
      TotalAmount,
      CtStatus,
      Comments,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _Materials : redirected to composition child ZC_ReingCTMaterial
}
