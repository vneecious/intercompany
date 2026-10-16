@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment Type Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true

-- Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C13F: ayuda de valores para tipo de pago
define view entity ZI_IntercoPaymentTypeVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T(
    p_domain_name: 'ZINT_DOM_PAYMENTTYPE'
  )
{
      @UI.hidden: true
  key domain_name                      as DomainName,

      @UI.hidden: true
  key value_position                   as ValuePosition,

      @UI.hidden: true
  key language                         as Language,

      @EndUserText.label: 'Payment Type'
      @ObjectModel.text.element: [ 'PaymentTypeName' ]
      @Search.defaultSearchElement: true
      substring( value_low, 1, 1 )     as PaymentType,

      @EndUserText.label: 'Description'
      @Semantics.text: true
      @Search.defaultSearchElement: true
      text                             as PaymentTypeName
}
where language = $session.system_language
-- Fin EXT_OSCUGALD 06.10.2026 - C13F
