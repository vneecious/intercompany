@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Search Help Intercopamy Recipient Company'
define view entity ZI_IntercoRecipientCompany_SH as select from ZI_IntercoRelationship
{
  key RecipientCompanyCode,
      RecipientCompanyCodeName,
      RecipientCountry,
      RecipientCountryName

}
group by
  RecipientCompanyCode,
  RecipientCompanyCodeName,
  RecipientCountry,
  RecipientCountryName
