@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VH Centro de Costo IC'
@ObjectModel.usageType.serviceQuality: #C
@ObjectModel.usageType.sizeCategory: #L
@ObjectModel.usageType.dataClass: #MASTER
@ObjectModel.dataCategory: #VALUE_HELP

// ----------------------------------------------------------------------
// Autor  : EXT_AGFAGINA
// Fecha  : 31.08.2026
// Motivo : Issue 44 del tracker - "Vista de datos del centro de costes danada".
//          El campo Kostl de ZC_ReingCTMaterial2 apuntaba directamente a
//          I_CostCenter, que es la vista de datos MAESTROS (~80 columnas) y ni
//          siquiera trae la descripcion. El popup se renderizaba con decenas de
//          columnas de un caracter de ancho, ilegible.
//          Esta vista expone solo lo necesario para elegir un centro de costo.
// Idioma : el texto se toma en el idioma de sesion y, si no hay traduccion, se
//          cae a espanol. Medido en DS4: 27.511 textos en 'S' contra 67 en 'E'.
//          Con un filtro simple por idioma de sesion, un usuario con la UI en
//          ingles veria el value help sin descripciones.
//          El filtro de idioma es imprescindible: sin el, la vista devuelve una
//          fila por idioma traducido y la clave queda duplicada (es el defecto
//          que tenia ZI_ReingExrtTypeVH y hacia que el VH mostrara un solo valor).
// Nota   : se filtra por vigencia para no ofrecer centros de costo expirados.
// ----------------------------------------------------------------------
define view entity ZI_ReingCostCenterVH
  as select from I_CostCenter as cc
    left outer join I_CostCenterText as txt
      on  txt.ControllingArea  = cc.ControllingArea
      and txt.CostCenter       = cc.CostCenter
      and txt.ValidityEndDate  = cc.ValidityEndDate
      and txt.Language         = $session.system_language
    left outer join I_CostCenterText as txt_fb
      on  txt_fb.ControllingArea = cc.ControllingArea
      and txt_fb.CostCenter      = cc.CostCenter
      and txt_fb.ValidityEndDate = cc.ValidityEndDate
      and txt_fb.Language        = 'S'
{
      @EndUserText.label: 'Centro de Costo'
  key cc.CostCenter,

      @UI.hidden: true
  key cc.ControllingArea,

      @UI.hidden: true
  key cc.ValidityEndDate,

      @EndUserText.label: 'Descripcion'
      @Semantics.text: true
      coalesce( txt.CostCenterDescription,
                txt_fb.CostCenterDescription ) as CostCenterDescription,

      @EndUserText.label: 'Sociedad'
      cc.CompanyCode,

      @EndUserText.label: 'Centro de Beneficio'
      cc.ProfitCenter
}
where cc.ValidityEndDate >= $session.system_date
