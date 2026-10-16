@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VH Centro de Beneficio IC'
@ObjectModel.usageType.serviceQuality: #C
@ObjectModel.usageType.sizeCategory: #L
@ObjectModel.usageType.dataClass: #MASTER
@ObjectModel.dataCategory: #VALUE_HELP

// ----------------------------------------------------------------------
// Autor  : EXT_AGFAGINA
// Fecha  : 01.09.2026
// Motivo : El campo Prctr de ZC_ReingCTMaterial2 apuntaba directamente a
//          I_ProfitCenter, que es la vista de datos MAESTROS (decenas de
//          columnas: domicilio, telefonos, telex, region, idioma...) y no trae
//          la descripcion. El popup del value help se renderizaba con las
//          columnas de un caracter de ancho, ilegible.
//          Mismo caso y mismo patron que ZI_ReingCostCenterVH (issue 44).
//          Esta vista expone solo lo necesario para elegir un centro de beneficio.
//
// Idioma : el texto se toma en el idioma de sesion y, si no hay traduccion, se
//          cae a espanol, igual que en el VH de centro de costo.
//          El filtro de idioma es imprescindible: sin el, la vista devuelve una
//          fila por idioma traducido y la clave queda duplicada.
//
// Vigencia: se excluyen los centros de beneficio expirados.
// ----------------------------------------------------------------------
define view entity ZI_ReingProfitCenterVH
  as select from I_ProfitCenter as pc
    left outer join I_ProfitCenterText as txt
      on  txt.ControllingArea  = pc.ControllingArea
      and txt.ProfitCenter     = pc.ProfitCenter
      and txt.ValidityEndDate  = pc.ValidityEndDate
      and txt.Language         = $session.system_language
    left outer join I_ProfitCenterText as txt_fb
      on  txt_fb.ControllingArea = pc.ControllingArea
      and txt_fb.ProfitCenter    = pc.ProfitCenter
      and txt_fb.ValidityEndDate = pc.ValidityEndDate
      and txt_fb.Language        = 'S'
{
      @EndUserText.label: 'Centro de Beneficio'
  key pc.ProfitCenter,

      @UI.hidden: true
  key pc.ControllingArea,

      @UI.hidden: true
  key pc.ValidityEndDate,

      @EndUserText.label: 'Descripcion'
      @Semantics.text: true
      coalesce( txt.ProfitCenterName,
                txt_fb.ProfitCenterName ) as ProfitCenterName,

      // Mod 01.09.2026 EXT_AGFAGINA: se expone Segmento como dato auxiliar para
      // desambiguar. NO se expone CompanyCode: en I_ProfitCenter viene vacio en
      // los 238 centros de beneficio del sistema, seria una columna en blanco.
      // Segmento en cambio esta informado en 230 de 238.
      @EndUserText.label: 'Segmento'
      pc.Segment
}
where pc.ValidityEndDate >= $session.system_date
