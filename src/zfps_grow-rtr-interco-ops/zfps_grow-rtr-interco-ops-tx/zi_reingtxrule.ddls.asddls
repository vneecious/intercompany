@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'TX - Reglas Fiscales (Interface)'
@Metadata.allowExtensions: true
define root view entity ZI_ReingTXRule
  as select from zreing_tx_rule_a
  association [0..1] to ZI_ReingTXType as _TaxType      on  $projection.TaxType = _TaxType.TaxType
  association [0..1] to I_Country      as _Country      on  $projection.Country = _Country.Country
  association [0..1] to I_Product      as _Material     on  $projection.Matnr   = _Material.Product
  association [0..1] to I_Supplier     as _Supplier     on  $projection.Lifnr   = _Supplier.Supplier
  // V009 (15.09.2026) - ET-REING-BR-001 v5 SS4.7.2: specificity engine on 6 fields
  association [0..1] to I_Country      as _CountryPrest on  $projection.CountryPrest = _CountryPrest.Country
  association [0..1] to I_CompanyCode  as _CompPrest    on  $projection.BukrsPrest   = _CompPrest.CompanyCode
  association [0..1] to I_CompanyCode  as _CompRecv     on  $projection.BukrsRecv    = _CompRecv.CompanyCode
{
  key tx_rule_id            as TxRuleId,
      country               as Country,
      country_prest         as CountryPrest,
      bukrs_prest           as BukrsPrest,
      bukrs_recv            as BukrsRecv,
      tax_type              as TaxType,
      matnr                 as Matnr,
      lifnr                 as Lifnr,
      rate                  as Rate,
      gross_up              as GrossUp,
      valid_from            as ValidFrom,
      valid_to              as ValidTo,
      tx_status             as TxStatus,
      description           as Description,
      notes                 as Notes,
      // V009 (15.09.2026) - specificity weights of ET-REING-BR-001 v5 SS4.3.
      // Was CASE lifnr/matnr -> 6/4/2/0, i.e. a disguised sum of +4 and +2.
      // Now the explicit sum of the six matching fields: an EMPTY field is a
      // wildcard and scores 0, so the more fields a rule fills in, the more
      // specific it is. Max 63 (32+16+8+4+2+1), well inside abap.int1.
      // NOTE this is the specificity of the RULE ITSELF, which is not the same
      // number as the match score ZCL_REING_CA_TX_SCORING computes against a
      // concrete LINE_A -- there a filled field only scores when it matches.
      cast(
        (   case when bukrs_recv    is not initial then 32 else 0 end
          + case when bukrs_prest   is not initial then 16 else 0 end
          + case when lifnr         is not initial then  8 else 0 end
          + case when matnr         is not initial then  4 else 0 end
          + case when country       is not initial then  2 else 0 end
          + case when country_prest is not initial then  1 else 0 end
        ) as abap.int1 )  as SpecificityScore,
      case tx_status
        when 'AC' then 3
        else 0
      end                   as TxStatusCriticality,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      changed_by            as ChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      changed_at            as ChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      _TaxType,
      _Country,
      _Material,
      _Supplier,
      _CountryPrest,
      _CompPrest,
      _CompRecv
}
