SELECT
 hps.PARTY_SITE_ID   						SITE_ID,       
 hps.PARTY_SITE_NAME   						SITE_NAME,     
 hps.PARTY_SITE_NUMBER   					SITE_NUMBER,   
 bill_to_party.ADDRESS1   					ADDRESS_LINE1, 
 bill_to_party.ADDRESS2   					ADDRESS_LINE2, 
 bill_to_party.ADDRESS3   					ADDRESS_LINE3, 
 bill_to_party.CITY  						CITY,          
 bill_to_party.STATE   						STATE,         
 bill_to_party.POSTAL_CODE   				POSTAL_CODE,   
 bill_to_party.COUNTRY   					COUNTRY,       
 bill_to_party.STATUS   					STATUS, 
 bill_to_cust.ACCOUNT_NUMBER 				ACC_NUMBER
 
FROM 
		hz_parties bill_to_party,
		hz_party_sites hps,
		doo_order_addresses bill_to,
		hz_cust_accounts bill_to_cust	 
WHERE   --dha.header_id = bill_to.header_id (+)
		bill_to_party.party_id = hps.party_id
  AND bill_to.address_use_type (+)= 'BILL_TO'
  AND bill_to.cust_acct_id = bill_to_cust.cust_account_id (+)
  AND bill_to_cust.party_id = bill_to_party.party_id
  
UNION

SELECT 
 hps.PARTY_SITE_ID   						SITE_ID,       
 hps.PARTY_SITE_NAME   						SITE_NAME,     
 hps.PARTY_SITE_NUMBER   					SITE_NUMBER,   
 ship_to_party.ADDRESS1   					ADDRESS_LINE1, 
 ship_to_party.ADDRESS2   					ADDRESS_LINE2, 
 ship_to_party.ADDRESS3   					ADDRESS_LINE3, 
 ship_to_party.CITY  						CITY,          
 ship_to_party.STATE   						STATE,         
 ship_to_party.POSTAL_CODE   				POSTAL_CODE,   
 ship_to_party.COUNTRY   					COUNTRY,       
 ship_to_party.STATUS   					STATUS, 
 ship_to_cust.ACCOUNT_NUMBER 				ACC_NUMBER

FROM  hz_parties ship_to_party,
	  hz_party_sites hps,
	  doo_order_addresses ship_to,
	  hz_cust_accounts ship_to_cust

WHERE ---dla.inventory_item_id = esib.inventory_item_id
  	  ship_to_party.party_id = hps.party_id
  AND ship_to.address_use_type (+)= 'SHIP_TO'
  AND ship_to.cust_acct_id = ship_to_cust.cust_account_id (+)
  AND ship_to_cust.party_id = ship_to_party.party_id
  
  
  
  
