@EndUserText.label: 'CT V2 - Contrato Root Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

// Autor  : AGF
// Fecha  : 18.06.2026
// P3 - SupplierName via asociacion, text element de Lifnr

define root view entity ZC_ReingCTContract2
  provider contract transactional_query
  as projection on ZI_ReingCTContract2
{
  key CtUuid,
      // Mod 25.09.2026 EXT_AGFAGINA - Ajustes Sprint 3: el nombre del proveedor se
      // declara como TEXTO del numero de contrato. La ruta de navegacion (breadcrumb)
      // de las paginas hijas toma el TITULO de la cabecera (CtId) y no su
      // descripcion, por eso no mostraba el proveedor aunque la cabecera lo tuviera.
      // Con el text element + textArrangement del DDLX el titulo pasa a verse
      // "IC-0018 (Microsoft Corporation)". Solo anotacion: no toca la tabla draft.
      // Mod 30.09.2026 EXT_AGFAGINA - DF-559: el texto del ID de contrato pasa a ser
      // el N. Contrato Externo en lugar del nombre del proveedor ("IC-0018 (S&T GITHUB
      // ENTERPRSE)"). El proveedor ya tiene su propia columna en el listado. Afecta
      // tambien a la ruta de navegacion de las paginas hijas (mismo mecanismo).
      @ObjectModel.text.element: ['ExtContract']
      CtId,
      Lifnr,
      _Supplier.SupplierName as SupplierName,
      Bukrs,
      ExtContract,
      ValidFrom,
      ValidTo,
      Waers,
      Responsible,
      EmailContact,
      RenewalDays,
      TotalAmount,
      CtStatus,
      Comments,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _Materials : redirected to composition child ZC_ReingCTMaterial2,
      _History   : redirected to composition child ZC_ReingC2Hist,
      _Supplier
}
