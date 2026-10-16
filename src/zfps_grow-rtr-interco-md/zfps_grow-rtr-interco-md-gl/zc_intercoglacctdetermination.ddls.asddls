@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Projection View for ZR_INTERCOGLACCTDETERMINATION'
@ObjectModel.semanticKey: [ 'ID' ]
define root view entity ZC_INTERCOGLACCTDETERMINATION
  provider contract transactional_query
  as projection on ZR_INTERCOGLACCTDETERMINATION
{
  key ID,
      ValidFrom,
      ValidTo,
      DocType,
      ProviderCompanyCode,
      RecipientCompanyCode,
      Product,
      Depto,
      PAndLID,
      PAndLLevel,
      TariffType,
      OperationType,
      GlAccount1,
      GlAccount2,
      IsDeleted,
      LocalLastChangedAt

}
