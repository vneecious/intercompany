@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Glaccoutn and company filter BR land'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity zi_skb1_br as select from skb1 
       inner      join ska1 on ska1.saknr = skb1.saknr
       inner      join t001 on t001.bukrs = skb1.bukrs and t001.ktopl = ska1.ktopl 
       inner      join t002 on skb1.bukrs <> ''
       left outer join skat on skat.saknr = skb1.saknr and skat.ktopl = t001.ktopl and skat.spras = t002.spras
{
key skb1.bukrs, 
key skb1.saknr as GLAccount, 
key t001.ktopl, 
key t002.spras, 
skat.txt20, 
skat.txt50,
ska1.glaccount_type    
} where t001.land1 = 'BR'
