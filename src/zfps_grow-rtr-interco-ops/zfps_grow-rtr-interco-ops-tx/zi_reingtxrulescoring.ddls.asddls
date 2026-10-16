@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'TX - Scoring (consumo CA)'
define view entity ZI_ReingTXRuleScoring
  as select from zreing_tx_rule_a
{
  key tx_rule_id  as TxRuleId,
      country     as Country,
      // V009 (15.09.2026) - ET-REING-BR-001 v5 SS4.2: the three new matching
      // fields of the specificity engine. Empty = wildcard.
      country_prest as CountryPrest,
      bukrs_prest   as BukrsPrest,
      bukrs_recv    as BukrsRecv,
      tax_type    as TaxType,
      matnr       as Matnr,
      lifnr       as Lifnr,
      rate        as Rate,
      gross_up    as GrossUp,
      valid_from  as ValidFrom,
      valid_to    as ValidTo,
      // V009 (15.09.2026) - weights of SS4.3 (32/16/8/4/2/1), replacing the
      // old 6/4/2/0 over lifnr+matnr only. Kept in sync with the identical
      // expression in ZI_ReingTXRule -- the duplication is pre-existing.
      cast(
        (   case when bukrs_recv    is not initial then 32 else 0 end
          + case when bukrs_prest   is not initial then 16 else 0 end
          + case when lifnr         is not initial then  8 else 0 end
          + case when matnr         is not initial then  4 else 0 end
          + case when country       is not initial then  2 else 0 end
          + case when country_prest is not initial then  1 else 0 end
        ) as abap.int1 ) as SpecificityScore
}
where tx_status = 'AC'
