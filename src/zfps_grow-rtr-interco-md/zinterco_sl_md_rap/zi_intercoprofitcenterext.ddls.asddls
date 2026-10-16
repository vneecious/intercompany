@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany - Profit Center for Metics'
define root view entity zI_intercoPROFITCENTERext
  as select from zI_intercoPROFITCENTER_exten as _profEx
  //  association [0..1] to ZI_INTERCOPROFITCENTERBU as _profBu on _profEx.ProfitCenter = _profEx.ProfitCenter
  association [0..1] to ZI_PNL_PROD as _profBu on _profEx.ProfitCenter = _profEx.ProfitCenter
{
  key _profEx.ControllingArea,
  key _profEx.ProfitCenter,
  key _profEx.ValidityEndDate,
      _profBu.Subbu,
      _profBu.SubbuName,
      _profBu.BusinessUnit,
      _profBu.BusinessUnitName,
      _profBu.BusinessUnitProductName,
      _profEx.ProfitCtrResponsiblePersonName,
      _profEx.CompanyCode,
      _profEx.ProfitCtrResponsibleUser,
      _profEx.ValidityStartDate,
      _profEx.Department,
      _profEx.ProfitCenterStandardHierarchy,
      _profEx.Segment,
      _profEx.ProfitCenterIsBlocked,
      _profEx.FormulaPlanningTemplate,
      _profEx.FormOfAddress,
      _profEx.AddressName,
      _profEx.AdditionalName,
      _profEx.ProfitCenterAddrName3,
      _profEx.ProfitCenterAddrName4,
      _profEx.StreetAddressName,
      _profEx.POBox,
      _profEx.CityName,
      _profEx.PostalCode,
      _profEx.POBoxPostalCode,
      _profEx.District,
      _profEx.Country,
      _profEx.Region,
      _profEx.TaxJurisdiction,
      _profEx.Language,
      _profEx.PhoneNumber1,
      _profEx.PhoneNumber2,
      _profEx.TeleboxNumber,
      _profEx.TelexNumber,
      _profEx.FaxNumber,
      _profEx.TeletexNumber,
      _profEx.DataCommunicationPhoneNumber,
      _profEx.ProfitCenterPrinterName,
      _profEx.ProfitCenterCreatedByUser,
      _profEx.ProfitCenterCreationDate,
      /* Associations */
      _profEx._Company,
      _profEx._ControllingArea,
      //      _profEx._ControllingAreaText,
      _profEx._Country,
      _profEx._Language,
      _profEx._PrftCtrCompanyCodeAssignment,
      _profEx._ProfitCenterHierarchyNode,
      _profEx._Region
      //      _profEx._Segment
      //      _profEx._SegmentText
      //      _profEx._Text
}
