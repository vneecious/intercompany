@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CM - Registro de Carga Mensual'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #MIXED

// Autor  : AGF
// Fecha  : 03.06.2026
// T7 - _OpType sin OpInstanceNum en ON (CMHeader no tiene ese campo)
//      Asociacion [0..*] es valida sin todos los campos clave del target

define view entity ZI_ReingCMHeader
  as select from zreing_cm_h_a as CM

  association to parent ZI_ReingCMPeriod as _Period
    on  $projection.PeriodYear  = _Period.PeriodYear
    and $projection.PeriodMonth = _Period.PeriodMonth

  association [1..1] to ZI_ReingCTContract2 as _Contract
    on $projection.CtUuid = _Contract.CtUuid

  association [1..1] to ZI_ReingCTMaterial2 as _Material
    on  $projection.CtUuid  = _Material.CtUuid
    and $projection.MatUuid = _Material.MatUuid

  association [0..*] to ZI_ReingCTOpType2 as _OpType
    on  $projection.CtUuid  = _OpType.CtUuid
    and $projection.MatUuid = _OpType.MatUuid
    and $projection.OpType  = _OpType.OpType

  // Begin Mod 08.09.2026 EXT_AGFAGINA - distribucion del devengamiento.
  // _OpType es [0..*] (CM no tiene OpInstanceNum) y por eso no permite exponer
  // sus campos. ZI_ReingCMOpTypeDist agrupa por contrato + material + tipo y
  // deja la cardinalidad en [0..1], que si permite traer el valor.
  association [0..1] to ZI_ReingCMOpTypeDist as _OpTypeDist
    on  $projection.CtUuid        = _OpTypeDist.CtUuid
    and $projection.MatUuid       = _OpTypeDist.MatUuid
    and $projection.OpType        = _OpTypeDist.OpType
    // Mod 01.10.2026 EXT_AGFAGINA - defecto 109: la activacion exacta.
    and $projection.OpInstanceNum = _OpTypeDist.OpInstanceNum
  // End Mod 08.09.2026 EXT_AGFAGINA

  // Begin Mod 25.09.2026 EXT_AGFAGINA - Ajustes Sprint 3: descripcion del tipo
  // de operacion. Se declara SOLO la asociacion; el campo se expone en la
  // proyeccion ZC_ReingCMHeader. Agregar un campo aca obligaria a sumarlo a la
  // tabla draft ZREING_CM_H_D (mismo caso que DistType, mod 08.09.2026).
  // El idioma de sesion en el ON deja la cardinalidad en [0..1].
  association [0..1] to ZI_ReingOpTypeText as _OpTypeText
    on  $projection.OpType   = _OpTypeText.OpType
    and _OpTypeText.Language = $session.system_language
  // End Mod 25.09.2026 EXT_AGFAGINA

  // Mod 02.10.2026 EXT_AGFAGINA - defecto 518: historial de cambios del registro
  // (ET 7.9). Va a la vista de consulta del log, que es la que publica el servicio;
  // solo asociacion (sin campo), asi no se toca la tabla draft.
  association [0..*] to ZC_ReingCMLog as _Log
    on $projection.CmHId = _Log.CmHId

  association [0..1] to I_Supplier as _Supplier
    on $projection.Lifnr = _Supplier.Supplier

  composition [0..*] of ZI_ReingCMRecv as _Receivers

{
  key CM.cm_h_id        as CmHId,
      CM.period_year    as PeriodYear,
      CM.period_month   as PeriodMonth,
      CM.ct_uuid        as CtUuid,
      CM.ct_ext_num     as CtExtNum,
      CM.mat_uuid       as MatUuid,
      CM.matnr          as Matnr,
      CM.op_type        as OpType,
      // Mod 01.10.2026 EXT_AGFAGINA - defecto 109: instancia de la operacion del
      // contrato (ET v27 5.2). 001 para F/P/NC/ANT; en A identifica la activacion.
      // El Motor la usa para cruzar la carga con la opcion exacta del contrato.
      CM.op_instance_num as OpInstanceNum,
      CM.defer_type     as DeferType,
      CM.load_seq       as LoadSeq,
      CM.amount         as Amount,
      CM.currency       as Currency,
      CM.delta_flag     as DeltaFlag,
      CM.cm_status      as CmStatus,
      CM.cm_status_text as CmStatusText,

      case CM.cm_status
        when 'PEND' then 0
        when 'GRAV' then 0
        when 'ENVI' then 2
        when 'LIBD' then 3
        when 'ERR'  then 1
        when 'SUPS' then 0
        else 0
      end as StatusCriticality,

      CM.load_user      as LoadUser,
      CM.load_date      as LoadDate,
      CM.sent_by        as SentBy,
      CM.sent_at        as SentAt,
      CM.released_by    as ReleasedBy,
      CM.released_at    as ReleasedAt,
      CM.accounting_doc as AccountingDoc,
      CM.created_by     as CreatedBy,
      CM.created_at     as CreatedAt,
      CM.changed_by     as ChangedBy,
      CM.changed_at     as ChangedAt,

      _Contract.Lifnr   as Lifnr,
      _Contract.Waers   as CtWaers,

      // Mod 08.09.2026 EXT_AGFAGINA: la distribucion NO se expone aca.
      // Agregar un campo a esta vista obliga a que la tabla draft
      // ZREING_CM_H_D lo tenga tambien, y RAP rechaza el BDEF:
      //   "ZREING_CM_H_D is not a suitable draft persistency (there is no DISTTYPE field)"
      // Se expone en la proyeccion ZC_ReingCMHeader, que no tiene draft propia,
      // usando la asociacion _OpTypeDist declarada arriba.

      _Period,
      _Contract,
      _Material,
      _OpType,
      _OpTypeDist,
      _OpTypeText,
      // Mod 02.10.2026 EXT_AGFAGINA - defecto 518
      _Log,
      _Supplier,
      _Receivers
}
