@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FX - Reglas de moneda de transaccion'
// V001 (CC) - CA-02 (EBA Brasil): backend FX rule contract.
define view entity ZI_ReingFxRule
  as select from zreing_fx_rule_a
  association [0..1] to I_Country     as _CountryPrest on $projection.CountryPrest = _CountryPrest.Country
  association [0..1] to I_Country     as _CountryRecv  on $projection.CountryRecv  = _CountryRecv.Country
  association [0..1] to I_CompanyCode as _BukrsPrest   on $projection.BukrsPrest   = _BukrsPrest.CompanyCode
  association [0..1] to I_CompanyCode as _BukrsRecv    on $projection.BukrsRecv    = _BukrsRecv.CompanyCode
{
  key fx_rule_id          as FxRuleId,
      ct_currency         as CtCurrency,
      same_country        as SameCountry,
      country_prest       as CountryPrest,
      country_recv        as CountryRecv,
      bukrs_prest         as BukrsPrest,
      bukrs_recv          as BukrsRecv,
      trans_currency_mode as TransCurrencyMode,
      trans_currency_fixed as TransCurrencyFixed,
      _CountryPrest,
      _CountryRecv,
      _BukrsPrest,
      _BukrsRecv
}
