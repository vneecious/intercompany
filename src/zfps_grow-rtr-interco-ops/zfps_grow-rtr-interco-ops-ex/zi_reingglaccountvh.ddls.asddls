@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VH Cuenta de Mayor IC'
@ObjectModel.usageType.serviceQuality: #C
@ObjectModel.usageType.sizeCategory: #L
@ObjectModel.usageType.dataClass: #MASTER
@ObjectModel.dataCategory: #VALUE_HELP

// ----------------------------------------------------------------------
// Autor  : EXT_AGFAGINA
// Fecha  : 31.08.2026
// Motivo : Issue 43 del tracker - "Filtre la cuenta de mayor por el plan de
//          cuentas MLIB para evitar cuentas duplicadas".
//          El campo Saknr de ZC_ReingCTMaterial2 usaba I_GLAccountStdVH, cuya
//          clave es GLAccount + CompanyCode: devolvia una fila POR SOCIEDAD y
//          la misma cuenta aparecia repetida decenas de veces en el popup.
//          Esta vista trabaja a nivel PLAN DE CUENTAS: una fila por cuenta.
//
// Chart  : se filtra por MLIB, el plan de la operacion (pedido explicito del
//          tracker). El sistema tiene mas de diez planes y sin este filtro la
//          misma cuenta volveria a duplicarse, ahora por plan.
//          Si el funcional confirma que puede haber otro plan en juego, hay que
//          parametrizarlo en vez de dejarlo fijo.
//
// Nota   : es la misma vista base a la que se migro la validacion del importador
//          de lineas GL (ZCL_REING_CT_GL_UPLOAD_HDL), de modo que el value help
//          y la validacion quedan sobre la misma fuente.
//
// Idioma : texto en el idioma de sesion con fallback a espanol. Sin filtro de
//          idioma la clave se duplicaria por cada traduccion, que es el defecto
//          que tenia ZI_ReingExrtTypeVH.
// ----------------------------------------------------------------------
define view entity ZI_ReingGLAccountVH
  as select from I_GLAccountInChartOfAccounts as gl
    left outer join I_GLAccountText as txt
      on  txt.ChartOfAccounts = gl.ChartOfAccounts
      and txt.GLAccount       = gl.GLAccount
      and txt.Language        = $session.system_language
    left outer join I_GLAccountText as txt_fb
      on  txt_fb.ChartOfAccounts = gl.ChartOfAccounts
      and txt_fb.GLAccount       = gl.GLAccount
      and txt_fb.Language        = 'S'
{
      @EndUserText.label: 'Cuenta de Mayor'
  key gl.GLAccount,

      @EndUserText.label: 'Plan de Cuentas'
  key gl.ChartOfAccounts,

      @EndUserText.label: 'Descripcion'
      @Semantics.text: true
      coalesce( txt.GLAccountLongName,
                txt_fb.GLAccountLongName ) as GLAccountName,

      @EndUserText.label: 'Grupo de Cuentas'
      gl.GLAccountGroup,

      @EndUserText.label: 'Tipo de Cuenta'
      gl.GLAccountType
}
where gl.ChartOfAccounts             = 'MLIB'
  and gl.AccountIsMarkedForDeletion  = ''
  and gl.AccountIsBlockedForPosting  = ''
