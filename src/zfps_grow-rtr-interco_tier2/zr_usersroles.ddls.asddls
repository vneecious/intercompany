@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Activated Users Roles'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZR_USERSROLES
  as select from agr_users
{
  key agr_name as AgrName,
  key uname    as Uname,
  key from_dat as FromDat,
  key to_dat   as ToDat
}
where
      from_dat <= $session.user_date
  and to_dat   >= $session.user_date
  and exclude  = ''
