------------------------
-- csg_gtm_account
-------------------------
create or replace type csg_gtm_account_tbltyp is
   table of csg_gtm_account_obj;

create or replace type csg_gtm_account_obj is object (
      account_number           varchar2(255),
      customer_account_id      number,
      address_line1            varchar2(255),
      address_line2            varchar2(255),
      address_line3            varchar2(255),
      address_line4            varchar2(255),
      city                     varchar2(255),
      comments                 varchar2(8000),
      country                  varchar2(255),
      county                   varchar2(255),
      created_by               varchar2(255),
      creation_date            date,
      dunsnumber               varchar2(255),
      internal                 varchar2(255),
      gsa_indicator            varchar2(255),
      lastupdatedby            varchar2(255),
      lastupdatedate           date,
      lineofbusiness           varchar2(255),
      partyname                varchar2(255),
      partyuniquename          varchar2(255),
      partytype                varchar2(255),
      personfirstname          varchar2(255),
      personlastname           varchar2(255),
      organizationname         varchar2(255),
      preferredname            varchar2(255),
      partyid                  number,
      partysitenumber          varchar2(255),
      postalcode               varchar2(50),
      primaryemail             varchar2(255),
      primaryphoneareacode     varchar2(255),
      primaryphonecountrycode  varchar2(255),
      primaryphoneextension    varchar2(255),
      primaryphoneid           number,
      primaryphonelinetype     varchar2(255),
      primaryphonenumber       varchar2(255),
      primaryphonepurpose      varchar2(255),
      province                 varchar2(255),
      registryid               varchar2(255),
      siccode                  varchar2(255),
      state                    varchar2(255),
      status                   varchar2(255),
      url                      varchar2(255),
      businessunit             varchar2(255),
      governmentaccount        varchar2(255),
      globaltradecompliance    varchar2(255),
      accountsuspended         varchar2(255),
      cvadtelemetrystatus      varchar2(255),
      netscalertelemetrystatus varchar2(255),
      ussoilonlycustomer       varchar2(255),
      customertype             varchar2(255),
      partnertype              varchar2(255),
      domesticultimatedunsnumc varchar2(255),
      globalultimatedunsnumc   varchar2(255),
      parentdunsnumc           varchar2(255),
      accountsegmentation      varchar2(255),
      pr_terr_name             varchar2(255),
      pr_terr_num              varchar2(255),
      pr_terr_id               number,
      pr_terr_owner            varchar2(255),
      pr_terr_owneremail       varchar2(255),
      ol_terr_name             varchar2(255),
      ol_terr_num              varchar2(255),
      ol_terr_id               number,
      ol_terr_owner            varchar2(255),
      ol_terr_owneremail       varchar2(255),
      accountexe               varchar2(255),
      accountdevmgr            varchar2(255),
      salesdir                 varchar2(255),
      atsmanager               varchar2(255),
      solarch                  varchar2(255),
      stratpartnermgr          varchar2(255),
      acctmanager              varchar2(255),
      accttechstrategist       varchar2(255),
      netscalerspecialist      varchar2(255),
      securityspecialist       varchar2(255),
      productmanager           varchar2(255),
      attribute1               varchar2(255),
      attribute2               varchar2(255),
      attribute3               varchar2(255),
      attribute4               varchar2(255),
      attribute5               varchar2(255)
);create or replace type csg_gtm_account_sites_tbltyp as
   table of csg_gtm_account_sites_obj;

create or replace package csg_oic_gtm_acct_pkg is
   procedure split_rec_prc (
      p_intg_name in varchar2
   );

   procedure fetch_rec_dtls_prc (
      p_batch_id number,
      p_accounts out csg_gtm_account_tbltyp,
      x_err_msg  out varchar2
   );

   procedure update_status_prc (
      p_batch_id  in number default null,
      p_status    in varchar2,
      p_error_msg in varchar2,
      x_error_msg out varchar2
   );

   procedure delete_rec_prc (
      p_batch_id  in number default null,
      x_error_msg out varchar2
   );

end csg_oic_gtm_acct_pkg;

create or replace package body csg_oic_gtm_acct_pkg as
   procedure split_rec_prc (
      p_intg_name in varchar2
   ) is
      lv_total_row_count number;
      lv_bs              number;
      lv_nob             number;
      lv_batch_size      number;
      lv_batch_id        number;
      lv_max_retries     number := 3;
      lv_cnt             number := 0;
   begin

    -- logic to delete records based on ID or batch
      insert into csg_oic_intg_archive_tbl
         (
            select id1,
                   id2,
                   id3,
                   batch_id,
                   'csg_gtm_acct_stg_tbl',
                   systimestamp
              from csg_gtm_acct_stg_tbl
             where status = 'S'
         );

      commit;
      delete from csg_gtm_acct_stg_tbl
       where status = 'S';

      commit;


		  --
    -- Calculate total rows to process
				--
      select batch_size
        into lv_batch_size
        from csg_oic_sched_jobs_tbl
       where status = 'A'
         and intg_name = p_intg_name;

      select count(1)
        into lv_total_row_count
        from csg_gtm_acct_stg_tbl
       where nvl(
         status,
         'X'
      ) in ( 'X' )
         and batch_id is null
         and rownum <= 1000;

    --
    -- Determine batch size
				--
      if lv_batch_size is null
      or lv_batch_size = 0 then
         lv_bs := lv_total_row_count;
      else
         lv_bs := lv_batch_size;
      end if;

    --
    -- Calculate number of batches
				--
      lv_nob := ceil(lv_total_row_count / lv_bs); -- Use CEIL to handle fractional batches

    --
    -- Loop through batches and update records
				--
      for x in 1..lv_nob loop
         lv_batch_id := csg_cmn_sch_batch_id_s.nextval;
         update csg_gtm_acct_stg_tbl
            set batch_id = lv_batch_id,
                status = 'P'
          where rownum <= lv_bs
            and nvl(
            status,
            'X'
         ) in ( 'X' )
            and batch_id is null;

         commit;
      end loop;
      commit;
------------reporcess err--
      lv_total_row_count := 0;
      select count(1)
        into lv_total_row_count
        from csg_gtm_acct_stg_tbl
       where status = 'E'
         and nvl(
         err_retries,
         0
      ) <= lv_max_retries
         and rownum <= 500;

      if lv_total_row_count > 0 then
--error rows are processed 1 at a time
--      lv_bs:=1;
--lv_nob := CEIL(lv_total_row_count / lv_bs); -- Use CEIL to handle fractional batches

         for x in (
            select id1
              from csg_gtm_acct_stg_tbl
             where status = 'E'
               and nvl(
               err_retries,
               0
            ) <= lv_max_retries
             order by nvl(
               err_retries,
               0
            ),
                      lastupdatedate
         ) loop
            lv_cnt := lv_cnt + 1;
            lv_batch_id := csg_cmn_sch_batch_id_s.nextval;
            update csg_gtm_acct_stg_tbl
               set batch_id = lv_batch_id,
                   status = 'P',
                   lastupdatedate = sysdate
             where id1 = x.id1
               and status = 'E';

            commit;
            if lv_cnt >= lv_total_row_count then
               exit;
            end if;
         end loop;
      end if;

   exception
      when others then
         csg_db_log_prc(
            sqlerrm,
            'CSG_OIC_GTM_ACCT_PKG.split_rec_prc'
         );
   end split_rec_prc;

  --
  -- Common Procedure (PRC_2) for Fetch ATP records to be processed.
		--
   procedure fetch_rec_dtls_prc (
      p_batch_id in number,
      p_accounts out csg_gtm_account_tbltyp,
      x_err_msg  out varchar2
   ) is
      v_accounts csg_gtm_account_tbltyp;
   begin
      select csg_gtm_account_obj(
         ca."AccountNumber" -- "Account_Number"
         ,
         ca."CustAccountId",
         p_org."Address1",
         p_org."Address2",
         p_org."Address3",
         p_org."Address4",
         p_org."City",
         ca."Comments",
         p_org."Country",
         p_org."County",
         ca."CreatedBy",
         ca."CreationDate",
         p_org."DunsNumberC",
         p_org."InternalFlag",
         p_org."GsaIndicatorFlag",
         ca."LastUpdatedBy",
         ca."LastUpdateDate",
         org."LineOfBusiness" -- lineOfBusiness
         ,
         p_org."PartyName" -- Need to map for Attribute1 in GTM
         ,
         p_org."PartyUniqueName",
         p_org."PartyType" -- Add the correct column table from parties
         ,
         p_org."PersonFirstName" -- Added for FirstName
         ,
         p_org."PersonLastName" -- Added for LastName
         ,
         org."OrganizationName" -- Organization Name
         ,
         p_org."PreferredName",
         ca."PartyId",
         (
            select ps."PartySiteNumber"
              from partysite ps
             where ps."PartyId" = ca."PartyId"
               and ps."OverallPrimaryFlag" = 'Y'
               and ps."Status" = 'A'
         )  -- party SiteNumber
         ,
         p_org."PostalCode",
         p_org."EmailAddress",
         p_org."PrimaryPhoneAreaCode",
         p_org."PrimaryPhoneCountryCode",
         p_org."PrimaryPhoneExtension",
         p_org."PrimaryPhoneContactPtId",
         p_org."PrimaryPhoneLineType",
         p_org."PrimaryPhoneNumber",
         p_org."PrimaryPhonePurpose",
         p_org."Province",
         p_org."PartyNumber" -- "RegistryID"
         ,
         p_org."SicCode",
         p_org."State",
         p_org."Status",
         p_org."Url" -- "URL"
         ,
         ca."Attribute9" -- BusinessUnit
          --,decode(ca."Attribute13",'Non-Gov','','T') -- GovernmentAccount
         ,
         ca."Attribute13" -- GovernmentAccount
         ,
         ca."Attribute7" -- GlobalTradeCompliance
          --,decode(ca."Attribute22",'Y','T','') -- AccountSuspended
         ,
         ca."Attribute22" -- AccountSuspended
         ,
         ca."Attribute19" -- CVADTelemetryStatus
         ,
         ca."Attribute20" -- NetscalerTelemetryStatus
         ,
         ca."Attribute23" -- USSoilOnlyCustomer
         ,
         ca."Attribute2" -- customerType
         ,
         (
            select pe."ExtnAttributeChar009"
              from partnerprogramenrollments pe
             where --pe."ProgramEnrollmentsEnrollmentStatus" = 'APPROVED'
              pe."ExtnAttributeChar016" = 'APPROVED'
               and pe."PartyPartyId" = ca."PartyId"
               and rownum <= 1
         )-- PartnerType,
         ,
         org."DomesticUltimateDunsNumC",
         org."GlobalUltimateDunsNumC",
         org."ParentDunsNumC",
         org."ExtnAttributeChar003" -- AccountSegmentation
          /*,((select meaning from fnd_lookup_values where lookup_code=EXTN_ATTRIBUTE_CHAR004
and LOOKUP_TYPE ='ACCOUNT_SEGMENTATION') acct_seg
 from HZ_ORGANIZATION_PROFILES where party_id=(100000436226623)) ---- AccountSegmentation*/,
         prime_terr."Name" -- pr_terr_name
         ,
         prime_terr."TerritoryNumber" -- pr_terr_num
         ,
         prime_terr."TerritoryId" -- pr_terr_id
         ,
         (
            select "PersonName"
              from resourcedetails
             where "PartyId" = prime_terr."OwnerResourceId"
         ) -- pr_terr_owner
         ,
         (
            select "EmailAddress"
              from resourcedetails
             where "PartyId" = prime_terr."OwnerResourceId"
         ) -- pr_terr_ownerEmail
         ,
         ol_terr."Name" -- ol_terr_name
         ,
         ol_terr."TerritoryNumber" -- ol_terr_num
         ,
         ol_terr."TerritoryId" -- ol_terr_id
         ,
         (
            select "PersonName"
              from resourcedetails
             where "PartyId" = ol_terr."OwnerResourceId"
         ) -- ol_terr_owner
         ,
         (
            select "EmailAddress"
              from resourcedetails
             where "PartyId" = ol_terr."OwnerResourceId"
         ) -- ol_terr_ownerEmail
         ,
         nvl(
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'ACCOUNT_EXECUTIVE'
                  and rownum <= 1
            ),
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'ACCOUNT_EXECUTIVE'
                  and rownum <= 1
            )
         ) -- AccountExe
         ,
         nvl(
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'ACCOUNT_DEVELOPMENT_MGR'
                  and rownum <= 1
            ),
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'ACCOUNT_DEVELOPMENT_MGR'
                  and rownum <= 1
            )
         ) -- AccountDevMgr
         ,
         nvl(
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'SALES_DIRECTOR'
                  and rownum <= 1
            ),
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'SALES_DIRECTOR'
                  and rownum <= 1
            )
         ) -- SalesDir
         ,
         nvl(
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'ATS_MANAGER'
                  and rownum <= 1
            ),
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'ATS_MANAGER'
                  and rownum <= 1
            )
         ) -- ATSManager
         ,
         nvl(
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'SOLUTION_ARCHITECT'
                  and rownum <= 1
            ),
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'SOLUTION_ARCHITECT'
                  and rownum <= 1
            )
         ) -- SolArch
         ,
         nvl(
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'STRATEGIC_PARTNER_MGR'
                  and rownum <= 1
            ),
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'STRATEGIC_PARTNER_MGR'
                  and rownum <= 1
            )
         ) -- stratPartnerMgr
         ,
         nvl(
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'ACCOUNT_MANAGER'
                  and rownum <= 1
            ),
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'ACCOUNT_MANAGER'
                  and rownum <= 1
            )
         ) -- AcctManager
         ,
         nvl(
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'ACCOUNT_TECH_SPECIALIST'
                  and rownum <= 1
            ),
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'ACCOUNT_TECH_SPECIALIST'
                  and rownum <= 1
            )
         ) -- AcctTechStrategist
         ,
         nvl(
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'NETSCALER_SPECIALIST'
                  and rownum <= 1
            ),
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'NETSCALER_SPECIALIST'
                  and rownum <= 1
            )
         ) -- NetScalerSpecialist
         ,
         nvl(
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'SECURITY_SPECIALIST'
                  and rownum <= 1
            ),
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'SECURITY_SPECIALIST'
                  and rownum <= 1
            )
         ) -- SecuritySpecialist
         ,
         nvl(
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'PRODUCT_MANAGER'
                  and rownum <= 1
            ),
            (
               select rd."EmailAddress"
                 from territoryresource tr,
                      resourcedetails rd
                where tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
                  and rd."PartyId" = tr."ResourceId"
                  and tr."FunctionCode" = 'PRODUCT_MANAGER'
                  and rownum <= 1
            )
         ) -- ProductManager
         ,
         null,
         null,
         null,
         null,
         null
      )
      bulk collect
        into v_accounts
        from customeraccount ca,
             parties p_org,
             organization org,
             (
                select distinct sa."PartyId",
                                t."Name",
                                t."TerritoryNumber",
                                t."TerritoryId",
                                t."OwnerResourceId",
                                t."TerritoryVersionId",
                                rank()
                                over(partition by sa."PartyId"
                                     order by t."TerritoryId" desc
                                ) as terr_rank
                  from salesaccount sa,
                       salesaccountterritory sat,
                       territory t
                 where sa."SalesAccountId" = sat."SalesAccountId"
                   and t."TerritoryId" = sat."TerritoryId"
                   and sat."TerritoryVersionId" = t."TerritoryVersionId"
                   and t."TypeCode" = 'PRIME'
                   and t."TerritoryFunctionCode" like 'CITRIX%'
                   and t."StatusCode" = 'FINALIZED'
                   and t."EffectiveEndDate" > sysdate
                   and t."LatestVersionFlag" = 'Y'
             ) prime_terr,
             (
                select distinct sa."PartyId",
                                t."Name",
                                t."TerritoryNumber",
                                t."TerritoryId",
                                t."OwnerResourceId",
                                t."TerritoryVersionId",
                                rank()
                                over(partition by sa."PartyId"
                                     order by t."TerritoryId" desc
                                ) as terr_rank
                  from salesaccount sa,
                       salesaccountterritory sat,
                       territory t
                 where sa."SalesAccountId" = sat."SalesAccountId"
                   and t."TerritoryId" = sat."TerritoryId"
                   and sat."TerritoryVersionId" = t."TerritoryVersionId"
                   and t."TypeCode" = 'OVERLAY'
                   and t."TerritoryFunctionCode" like 'CITRIX%'
                   and t."StatusCode" = 'FINALIZED'
                   and t."EffectiveEndDate" > sysdate
                   and t."LatestVersionFlag" = 'Y'
             ) ol_terr
       where ca."PartyId" = p_org."PartyId"
         and org."PartyId" = p_org."PartyId"
         and p_org."PartyId" = prime_terr."PartyId" (+)
         and prime_terr.terr_rank (+) = 1
         and p_org."PartyId" = ol_terr."PartyId" (+)
         and ol_terr.terr_rank (+) = 1
         and ca."CustAccountId" in (
         select id1
           from csg_gtm_acct_stg_tbl
          where batch_id = p_batch_id
      );

      p_accounts := v_accounts;
      update csg_gtm_acct_stg_tbl
         set status = 'I',
             lastupdatedate = systimestamp
       where batch_id = p_batch_id;
      commit;
   exception
      when others then
         csg_db_log_prc(
            sqlerrm,
            'CSG_OIC_GTM_ACCT_PKG.fetch_rec_dtls_prc'
         );
   end fetch_rec_dtls_prc;

  --
  -- Common Procedure (PRC_3) for UPDATE Staging Table records after Processing.
		--
   procedure update_status_prc (
      p_batch_id  in number default null,
      p_status    in varchar2,
      p_error_msg in varchar2,
      x_error_msg out varchar2
   ) is
   begin
		  --
    -- Logic to update status and error message
				--
      if p_batch_id is not null then
      -- Update by batch_id
         update csg_gtm_acct_stg_tbl
            set status = decode(
            upper(p_status),
            'SUCCESS',
            'S',
            'ERROR',
            'E',
            p_status
         ),
                err_msg = p_error_msg,
                lastupdatedate = systimestamp,
                err_retries = nvl(
                   err_retries,
                   0
                ) + 1
          where batch_id = p_batch_id;
         commit;
      else
         x_error_msg := 'Batch_id must be provided';
      end if;
   exception
      when others then
         csg_db_log_prc(
            sqlerrm,
            'CSG_OIC_GTM_ACCT_PKG.update_status_prc'
         );
         x_error_msg := 'Error updating status: ' || sqlerrm;
   end update_status_prc;

  --
  -- Common Procedure (PRC_3) for DELETE 'SUCCESS' records from Staging Table after Processing.
		--
   procedure delete_rec_prc (
      p_batch_id  in number default null,
      x_error_msg out varchar2
   ) is
   begin
      null;
  /*
    -- logic to delete records based on ID or batch
    INSERT INTO csg_oic_intg_archive_tbl
    (SELECT
       id1
       ,id2
       ,id3
       ,batch_id
       ,'csg_gtm_acct_stg_tbl'
       ,systimestamp
      FROM csg_gtm_acct_stg_tbl
     WHERE status = 'S'
      and batch_id = p_batch_id);
commit;
    DELETE FROM csg_gtm_acct_stg_tbl
     WHERE status = 'S'
      and batch_id = p_batch_id;
commit;
*/
   exception
      when others then
         csg_db_log_prc(
            sqlerrm,
            'CSG_OIC_GTM_ACCT_PKG.delete_rec_prc'
         );
         x_error_msg := 'Error updating status: ' || sqlerrm;
   end delete_rec_prc;

end csg_oic_gtm_acct_pkg;

------------------------
-- csg_gtm_account_sites
-------------------------

create or replace type csg_gtm_account_sites_obj force is object (
      siteid       number(18),
      sitename     varchar2(255),
      sitenumber   varchar2(30),
      addressline1 varchar2(255),
      addressline2 varchar2(255),
      addressline3 varchar2(255),
      city         varchar2(255),
      state        varchar2(255),
      postalcode   varchar2(50),
      country      varchar2(255),
      status       varchar2(255),
      acc_number   varchar2(200)
);


create or replace package csg_oic_gtm_acct_sites_pkg is
   procedure split_rec_prc (
      p_intg_name in varchar2
   );

   procedure fetch_rec_dtls_prc (
      p_batch_id number,
      p_accounts out csg_gtm_account_sites_tbltyp,
      x_err_msg  out varchar2
   );

   procedure update_status_prc (
      p_batch_id  in number default null,
      p_status    in varchar2,
      p_error_msg in varchar2,
      x_error_msg out varchar2
   );

   procedure delete_rec_prc (
      p_batch_id  in number default null,
      x_error_msg out varchar2
   );

end csg_oic_gtm_acct_sites_pkg;


create or replace package body csg_oic_gtm_acct_sites_pkg as

   procedure split_rec_prc (
      p_intg_name in varchar2
   ) is

      lv_total_row_count number;
      lv_bs              number;
      lv_nob             number;
      lv_batch_size      number;
      lv_batch_id        number;
      lv_max_retries     number := 3;
      lv_cnt             number := 0;
   begin

    -- logic to delete records based on ID or batch
      insert into csg_oic_intg_archive_tbl
         (
            select id1,
                   id2,
                   id3,
                   batch_id,
                   'CSG_GTM_ACCT_SITES_STG_TBL',
                   systimestamp
              from csg_gtm_acct_sites_stg_tbl
             where status = 'S'
         );

      commit;
      delete from csg_gtm_acct_sites_stg_tbl
       where status = 'S';

      commit;

		  --
    -- Calculate total rows to process
				--
      select batch_size
        into lv_batch_size
        from csg_oic_sched_jobs_tbl
       where status = 'A'
         and intg_name = p_intg_name;

      select count(1)
        into lv_total_row_count
        from csg_gtm_acct_sites_stg_tbl
       where nvl(
         status,
         'X'
      ) in ( 'X' )
         and batch_id is null
         and rownum <= 1000;

    --
    -- Determine batch size
				--
      if lv_batch_size is null
      or lv_batch_size = 0 then
         lv_bs := lv_total_row_count;
      else
         lv_bs := lv_batch_size;
      end if;

    --
    -- Calculate number of batches
				--
      lv_nob := ceil(lv_total_row_count / lv_bs); -- Use CEIL to handle fractional batches

    --
    -- Loop through batches and update records
				--
      for x in 1..lv_nob loop
         lv_batch_id := csg_cmn_sch_batch_id_s.nextval;
         update csg_gtm_acct_sites_stg_tbl
            set batch_id = lv_batch_id,
                status = 'P'
          where rownum <= lv_bs
            and nvl(
            status,
            'X'
         ) in ( 'X' )
            and batch_id is null;

         commit;
      end loop;

      commit;
------------reporcess err--
      lv_total_row_count := 0;
      select count(1)
        into lv_total_row_count
        from csg_gtm_acct_sites_stg_tbl
       where status = 'E'
         and nvl(
         err_retries,
         0
      ) <= lv_max_retries
         and rownum <= 500;

      if lv_total_row_count > 0 then
--error rows are processed 1 at a time
--      lv_bs:=1;
--lv_nob := CEIL(lv_total_row_count / lv_bs); -- Use CEIL to handle fractional batches

         for x in (
            select id1
              from csg_gtm_acct_sites_stg_tbl
             where status = 'E'
               and nvl(
               err_retries,
               0
            ) <= lv_max_retries
             order by nvl(
               err_retries,
               0
            ),
                      lastupdatedate
         ) loop
            lv_cnt := lv_cnt + 1;
            lv_batch_id := csg_cmn_sch_batch_id_s.nextval;
            update csg_gtm_acct_sites_stg_tbl
               set batch_id = lv_batch_id,
                   status = 'P',
                   lastupdatedate = sysdate
             where id1 = x.id1
               and status = 'E';

            commit;
            if lv_cnt >= lv_total_row_count then
               exit;
            end if;
         end loop;
      end if;

   exception
      when others then
         csg_db_log_prc(
            sqlerrm,
            'CSG_OIC_GTM_ACCT_SITES_PKG.split_rec_prc'
         );
   end split_rec_prc;

  --
  -- Common Procedure (PRC_2) for Fetch ATP records to be processed.
		--
   procedure fetch_rec_dtls_prc (
      p_batch_id in number,
      p_accounts out csg_gtm_account_sites_tbltyp,
      x_err_msg  out varchar2
   ) is
      v_accounts csg_gtm_account_sites_tbltyp;
   begin
      select csg_gtm_account_sites_obj(
         ca_s."CustAcctSiteId",
         p_site."PartySiteName",
         p_site."PartySiteNumber",
         l."Address1",
         l."Address2",
         l."Address3",
         l."City",
         l."State",
         l."PostalCode",
         l."Country",
         ca_s."Status",
         ca."AccountNumber"
      )
      bulk collect
        into v_accounts
        from customeraccount ca,
             parties p_org,
             partysite p_site,
             customeraccountsite ca_s,
             location l
          --,organization org

       where ca."PartyId" = p_org."PartyId"
         and p_org."PartyId" = p_site."PartyId"
         and ca_s."CustAccountId" = ca."CustAccountId"
         and p_site."LocationId" = l."LocationId"
         and p_site."PartySiteId" = ca_s."PartySiteId"
      --and ca_s."CustAcctSiteId" ='100000426085898'
         and ca_s."CustAcctSiteId" in (
         select id1
           from csg_gtm_acct_sites_stg_tbl
          where batch_id = p_batch_id
      );





						    /* ca."AccountNumber" -- "Account_Number"
          ,ca."CustAccountId"
          ,p_org."Address1"
          ,p_org."Address2"
          ,p_org."Address3"
          ,p_org."Address4"
          ,p_org."City"
          ,ca."Comments"
          ,p_org."Country"
          ,p_org."County"
          ,ca."CreatedBy"
          ,ca."CreationDate"
          ,p_org."DunsNumberC"
          ,p_org."InternalFlag"
          ,p_org."GsaIndicatorFlag"
          ,ca."LastUpdatedBy"
          ,ca."LastUpdateDate"
          ,org."LineOfBusiness" -- lineOfBusiness
          ,p_org."PartyName"
          ,p_org."PartyUniqueName"
          ,org."OrganizationName" -- Organization Name
          ,p_org."PreferredName"
          ,ca."PartyId"
          ,p_org."PostalCode"
          ,p_org."EmailAddress"
          ,p_org."PrimaryPhoneAreaCode"
          ,p_org."PrimaryPhoneCountryCode"
          ,p_org."PrimaryPhoneExtension"
          ,p_org."PrimaryPhoneContactPtId"
          ,p_org."PrimaryPhoneLineType"
          ,p_org."PrimaryPhoneNumber"
          ,p_org."PrimaryPhonePurpose"
          ,p_org."Province"
          ,p_org."PartyNumber" -- "RegistryID"
          ,p_org."SicCode"
          ,p_org."State"
          ,p_org."Status"
          ,p_org."Url" -- "URL"
          ,ca."Attribute9" -- BusinessUnit
          --,decode(ca."Attribute13",'Non-Gov','','T') -- GovernmentAccount
          ,ca."Attribute13" -- GovernmentAccount
          ,ca."Attribute7" -- GlobalTradeCompliance
          --,decode(ca."Attribute22",'Y','T','') -- AccountSuspended
          ,ca."Attribute22" -- AccountSuspended
          ,ca."Attribute19" -- CVADTelemetryStatus
          ,ca."Attribute20" -- NetscalerTelemetryStatus
          ,ca."Attribute23" -- USSoilOnlyCustomer
          ,ca."Attribute2" -- customerType
         ,(select pe."ExtnAttributeChar009"
			  from PARTNERPROGRAMENROLLMENTS pe
			 where --pe."ProgramEnrollmentsEnrollmentStatus" = 'APPROVED'
                     pe."ExtnAttributeChar016"  = 'APPROVED'
			   and pe."PartyPartyId" = ca."PartyId"
			   and rownum<=1)-- PartnerType,
          ,org."DomesticUltimateDunsNumC"
          ,org."GlobalUltimateDunsNumC"
          ,org."ParentDunsNumC"
          ,org."ExtnAttributeChar003" -- AccountSegmentation
          /*,((select meaning from fnd_lookup_values where lookup_code=EXTN_ATTRIBUTE_CHAR004
and LOOKUP_TYPE ='ACCOUNT_SEGMENTATION') acct_seg
 from HZ_ORGANIZATION_PROFILES where party_id=(100000436226623)) ---- AccountSegmentation*/
         /* ,prime_terr."Name" -- pr_terr_name
          ,prime_terr."TerritoryNumber" -- pr_terr_num
          ,prime_terr."TerritoryId" -- pr_terr_id
          ,(SELECT "PersonName"
			 FROM resourcedetails
			WHERE "PartyId" = prime_terr."OwnerResourceId") -- pr_terr_owner
          ,(SELECT "EmailAddress"
			 FROM resourcedetails
			WHERE "PartyId" = prime_terr."OwnerResourceId") -- pr_terr_ownerEmail
          ,ol_terr."Name" -- ol_terr_name
          ,ol_terr."TerritoryNumber" -- ol_terr_num
          ,ol_terr."TerritoryId" -- ol_terr_id
          ,(SELECT "PersonName"
			 FROM resourcedetails
			WHERE "PartyId" = ol_terr."OwnerResourceId") -- ol_terr_owner
          ,(SELECT "EmailAddress"
			 FROM resourcedetails
			WHERE "PartyId" = ol_terr."OwnerResourceId") -- ol_terr_ownerEmail
          ,NVL((SELECT rd."EmailAddress"
				 FROM territoryresource tr
					,resourcedetails rd
                 WHERE tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
                   AND rd."PartyId" = tr."ResourceId"
                   AND tr."FunctionCode" = 'ACCOUNT_EXECUTIVE'
				   AND ROWNUM <= 1),
				   (SELECT rd."EmailAddress"
						FROM territoryresource tr
							,resourcedetails rd
						WHERE tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
						AND rd."PartyId" = tr."ResourceId"
						AND tr."FunctionCode" = 'ACCOUNT_EXECUTIVE'
						AND ROWNUM <= 1)
						) -- AccountExe
          ,NVL((SELECT rd."EmailAddress"
				FROM territoryresource tr
				,resourcedetails rd
				WHERE tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
				AND rd."PartyId" = tr."ResourceId"
				AND tr."FunctionCode" = 'ACCOUNT_DEVELOPMENT_MGR'
				AND ROWNUM <= 1),
				(SELECT rd."EmailAddress"
					FROM territoryresource tr
					,resourcedetails rd
					WHERE tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
					AND rd."PartyId" = tr."ResourceId"
					AND tr."FunctionCode" = 'ACCOUNT_DEVELOPMENT_MGR'
					AND ROWNUM <= 1)
				) -- AccountDevMgr
          ,NVL((SELECT rd."EmailAddress"
				FROM territoryresource tr
				,resourcedetails rd
				WHERE tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
				AND rd."PartyId" = tr."ResourceId"
				AND tr."FunctionCode" = 'SALES_DIRECTOR'
				AND ROWNUM <= 1),
				(SELECT rd."EmailAddress"
				FROM territoryresource tr
					,resourcedetails rd
					WHERE tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
					AND rd."PartyId" = tr."ResourceId"
					AND tr."FunctionCode" = 'SALES_DIRECTOR'
					AND ROWNUM <= 1)
				) -- SalesDir
          ,NVL((SELECT rd."EmailAddress"
				FROM territoryresource tr
				,resourcedetails rd
				WHERE tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
				AND rd."PartyId" = tr."ResourceId"
				AND tr."FunctionCode" = 'ATS_MANAGER'
				AND ROWNUM <= 1),
				(SELECT rd."EmailAddress"
					FROM territoryresource tr
					,resourcedetails rd
					WHERE tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
					AND rd."PartyId" = tr."ResourceId"
					AND tr."FunctionCode" = 'ATS_MANAGER'
					AND ROWNUM <= 1)
				) -- ATSManager
          ,(select rd."EmailAddress"-- sa."PartyId" ,sar."ResourceId",sar."MemberFunctionCode"
                from salesaccount sa, salesaccountresource sar,resourcedetails rd
                where sa."SalesAccountId" =sar."SalesAccountId"
                and sar."MemberFunctionCode" ='SOLUTION_ARCHITECT'
                and rd."PartyId" = sar."ResourceId"
                and sa."PartyId" = ca."PartyId") -- SolArch
          ,NVL((SELECT rd."EmailAddress"
				FROM territoryresource tr
				,resourcedetails rd
				WHERE tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
				AND rd."PartyId" = tr."ResourceId"
				AND tr."FunctionCode" = 'STRATEGIC_PARTNER_MGR'
				AND ROWNUM <= 1),
				(SELECT rd."EmailAddress"
					FROM territoryresource tr
					,resourcedetails rd
					WHERE tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
					AND rd."PartyId" = tr."ResourceId"
					AND tr."FunctionCode" = 'STRATEGIC_PARTNER_MGR' AND ROWNUM <= 1)
				) -- stratPartnerMgr
          ,NVL((SELECT rd."EmailAddress"
				FROM territoryresource tr
				,resourcedetails rd
				WHERE tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
				AND rd."PartyId" = tr."ResourceId"
				AND tr."FunctionCode" = 'ACCOUNT_MANAGER'
				AND ROWNUM <= 1),
				(SELECT rd."EmailAddress"
					FROM territoryresource tr
					,resourcedetails rd
					WHERE tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
					AND rd."PartyId" = tr."ResourceId"
					AND tr."FunctionCode" = 'ACCOUNT_MANAGER' AND ROWNUM <= 1)
				) -- AcctManager
          ,NVL((SELECT rd."EmailAddress"
				FROM territoryresource tr
				,resourcedetails rd
				WHERE tr."TerritoryVersionId" = ol_terr."TerritoryVersionId"
				AND rd."PartyId" = tr."ResourceId"
				AND tr."FunctionCode" = 'ACCOUNT_TECH_SPECIALIST'
				AND ROWNUM <= 1),
				(SELECT rd."EmailAddress"
					FROM territoryresource tr
					,resourcedetails rd
					WHERE tr."TerritoryVersionId" = prime_terr."TerritoryVersionId"
					AND rd."PartyId" = tr."ResourceId"
					AND tr."FunctionCode" = 'ACCOUNT_TECH_SPECIALIST' AND ROWNUM <= 1)
				) -- AcctTechStrategist
          ,(select rd."EmailAddress"-- sa."PartyId" ,sar."ResourceId",sar."MemberFunctionCode"
                from salesaccount sa, salesaccountresource sar,resourcedetails rd
                where sa."SalesAccountId" =sar."SalesAccountId"
                and sar."MemberFunctionCode" ='NETSCALER_SPECIALIST'
                and rd."PartyId" = sar."ResourceId"
                and sa."PartyId" = ca."PartyId") -- NetScalerSpecialist
          ,(select rd."EmailAddress"-- sa."PartyId" ,sar."ResourceId",sar."MemberFunctionCode"
                from salesaccount sa, salesaccountresource sar,resourcedetails rd
                where sa."SalesAccountId" =sar."SalesAccountId"
                and sar."MemberFunctionCode" ='SECURITY_SPECIALIST'
                and rd."PartyId" = sar."ResourceId"
                and sa."PartyId" = ca."PartyId") -- SecuritySpecialist
          ,(select rd."EmailAddress"-- sa."PartyId" ,sar."ResourceId",sar."MemberFunctionCode"
                from salesaccount sa, salesaccountresource sar,resourcedetails rd
                where sa."SalesAccountId" =sar."SalesAccountId"
                and sar."MemberFunctionCode" ='PRODUCT_MANAGER'
                and rd."PartyId" = sar."ResourceId"
                and sa."PartyId" = ca."PartyId") -- ProductManager
      )*/







      /*FROM customeraccount ca
          ,parties p_org
          ,organization org
          ,(SELECT distinct sa."PartyId"
				,t."Name"
				,t."TerritoryNumber"
				,t."TerritoryId"
				,t."OwnerResourceId"
				,t."TerritoryVersionId"
				,RANK() OVER (PARTITION BY sa."PartyId" ORDER BY t."TerritoryId" DESC) AS terr_rank
              FROM salesaccount sa
					,salesaccountterritory sat
					,territory t
             WHERE sa."SalesAccountId" = sat."SalesAccountId"
               AND t."TerritoryId" = sat."TerritoryId"
			   AND sat."TerritoryVersionId" = t."TerritoryVersionId"
               AND t."TypeCode" = 'PRIME'
               AND t."TerritoryFunctionCode" like 'CITRIX%'
               AND t."StatusCode" = 'FINALIZED'
               AND t."EffectiveEndDate" > SYSDATE
               AND t."LatestVersionFlag" = 'Y') prime_terr
          ,(SELECT distinct sa."PartyId"
				,t."Name"
				,t."TerritoryNumber"
				,t."TerritoryId"
				,t."OwnerResourceId"
				,t."TerritoryVersionId"
				,RANK() OVER (PARTITION BY sa."PartyId" ORDER BY t."TerritoryId" DESC) AS terr_rank
              FROM salesaccount sa
					,salesaccountterritory sat
					,territory t
             WHERE sa."SalesAccountId" = sat."SalesAccountId"
               AND t."TerritoryId" = sat."TerritoryId"
			   AND sat."TerritoryVersionId" = t."TerritoryVersionId"
               AND t."TypeCode" = 'OVERLAY'
               AND t."TerritoryFunctionCode" like 'CITRIX%'
               AND t."StatusCode" = 'FINALIZED'
               AND t."EffectiveEndDate" > SYSDATE
               AND t."LatestVersionFlag" = 'Y') ol_terr
      WHERE ca."PartyId" = p_org."PartyId"
        AND org."PartyId" = p_org."PartyId"
        AND p_org."PartyId" = prime_terr."PartyId"(+)
		AND prime_terr.terr_rank(+) = 1
        AND p_org."PartyId" = ol_terr."PartyId"(+)
		AND ol_terr.terr_rank(+) = 1
		AND ca."CustAccountId" IN (SELECT id1
									FROM CSG_GTM_ACCT_SITES_STG_TBL
									WHERE batch_id = p_batch_id);
*/
      p_accounts := v_accounts;
      update csg_gtm_acct_sites_stg_tbl
         set status = 'I',
             lastupdatedate = systimestamp
       where batch_id = p_batch_id;

      commit;
   exception
      when others then
         csg_db_log_prc(
            sqlerrm,
            'CSG_OIC_GTM_ACCT_SITES_PKG.fetch_rec_dtls_prc'
         );
   end fetch_rec_dtls_prc;

  --
  -- Common Procedure (PRC_3) for UPDATE Staging Table records after Processing.
		--
   procedure update_status_prc (
      p_batch_id  in number default null,
      p_status    in varchar2,
      p_error_msg in varchar2,
      x_error_msg out varchar2
   ) is
   begin
		  --
    -- Logic to update status and error message
				--
      if p_batch_id is not null then
      -- Update by batch_id
         update csg_gtm_acct_sites_stg_tbl
            set status = decode(
            upper(p_status),
            'SUCCESS',
            'S',
            'ERROR',
            'E',
            p_status
         ),
                err_msg = p_error_msg,
                lastupdatedate = systimestamp,
                err_retries = nvl(
                   err_retries,
                   0
                ) + 1
          where batch_id = p_batch_id;

         commit;
      else
         x_error_msg := 'Batch_id must be provided';
      end if;
   exception
      when others then
         csg_db_log_prc(
            sqlerrm,
            'CSG_OIC_GTM_ACCT_SITES_PKG.update_status_prc'
         );
         x_error_msg := 'Error updating status: ' || sqlerrm;
   end update_status_prc;

  --
  -- Common Procedure (PRC_3) for DELETE 'SUCCESS' records from Staging Table after Processing.
		--
   procedure delete_rec_prc (
      p_batch_id  in number default null,
      x_error_msg out varchar2
   ) is
   begin
      null;
  /*
    -- logic to delete records based on ID or batch
    INSERT INTO csg_oic_intg_archive_tbl
    (SELECT
       id1
       ,id2
       ,id3
       ,batch_id
       ,'CSG_GTM_ACCT_SITES_STG_TBL'
       ,systimestamp
      FROM CSG_GTM_ACCT_SITES_STG_TBL
     WHERE status = 'S'
      and batch_id = p_batch_id);
commit;
    DELETE FROM CSG_GTM_ACCT_SITES_STG_TBL
     WHERE status = 'S'
      and batch_id = p_batch_id;
commit;
*/
   exception
      when others then
         csg_db_log_prc(
            sqlerrm,
            'CSG_OIC_GTM_ACCT_SITES_PKG.delete_rec_prc'
         );
         x_error_msg := 'Error updating status: ' || sqlerrm;
   end delete_rec_prc;

end csg_oic_gtm_acct_sites_pkg;

------------------------
-- csg_so_pickup
-------------------------

create or replace package csg_so_pickup_pkg as

    -- Claims up to p_batch_size READY orders for the instance, flips them
    -- to IN-PROGRESS, and returns them as a nested Header->(Parties+Lines)
    -- set.
    -- OIC loop terminator: stop when
    --     p_picked_headers = 0 AND p_remaining_headers = 0.
   procedure pickup_so_details (
      p_instance_id       in varchar2,
      p_batch_size        in number default 50,   -- number of ORDERS per call
      p_ready_status      in varchar2 default 'New',
      p_inprog_status     in varchar2 default 'IN-PROGRESS',
      p_picked_headers    out number,                -- orders claimed by THIS call
      p_remaining_headers out number,                -- READY orders still left
      p_orders            out csg_so_header_tbl
   );

    -- Advances a SINGLE header to a next/terminal status.
   procedure set_header_status (
      p_instance_id  in varchar2,
      p_header_id    in varchar2,
      p_status       in varchar2,
      p_message      in varchar2,
      p_rows_updated out number
   );

    -- Advances a CHUNK of headers in one call (used by the OIC chunk loop
    -- to mark a processor chunk PROCESSED / ERROR).
   procedure set_headers_status (
      p_instance_id  in varchar2,
      p_header_ids   in csg_hdr_id_tbl,
      p_status       in varchar2,
      p_message      in varchar2,
      p_rows_updated out number
   );

end csg_so_pickup_pkg;


create or replace package body csg_so_pickup_pkg as

    ------------------------------------------------------------------
   procedure pickup_so_details (
      p_instance_id       in varchar2,
      p_batch_size        in number default 50,
      p_ready_status      in varchar2 default 'New',
      p_inprog_status     in varchar2 default 'IN-PROGRESS',
      p_picked_headers    out number,
      p_remaining_headers out number,
      p_orders            out csg_so_header_tbl
   ) as
      l_batch    number := nvl(
         p_batch_size,
         50
      );
      l_cand     csg_hdr_id_tbl := csg_hdr_id_tbl();  -- candidate headers
      l_won      csg_hdr_id_tbl := csg_hdr_id_tbl();  -- headers actually claimed
      l_lines    csg_so_line_tbl := csg_so_line_tbl();
      l_prev_hdr varchar2(50);
      l_idx      pls_integer := 0;
      cursor c_data is
      select t.*
        from csg_so_details_gtm_tbl t
       where t.oic_instance_id = p_instance_id
         and t.process_status = p_inprog_status
         and t.header_id in (
         select column_value
           from table ( l_won )
      )
       order by t.header_id,
                t.fulfill_line_id;
   begin
      if l_batch < 1 then
         l_batch := 1;
      end if;
      p_orders := csg_so_header_tbl();

        --  Start : pick next N distinct READY headers
      select header_id
      bulk collect
        into l_cand
        from (
         select distinct header_id
           from csg_so_details_gtm_tbl
          where oic_instance_id = p_instance_id
            and process_status = p_ready_status
          order by header_id
      )
       where rownum <= l_batch;

      dbms_output.put_line('L_CAND' || l_cand.count);
      if l_cand.count = 0 then
         p_picked_headers := 0;
         p_remaining_headers := 0;
         return;
      end if;

        -- Optimistic claim: the "status = READY" predicate is the concurrency
        -- guard. If another poller already flipped a header, that row updates
        -- 0 rows and we simply don't own it.
      forall i in 1..l_cand.count
         update csg_so_details_gtm_tbl
            set process_status = p_inprog_status,
                last_update_date = sysdate
          where oic_instance_id = p_instance_id
            and process_status = p_ready_status
            and header_id = l_cand(i);

      for i in 1..l_cand.count loop
         if sql%bulk_rowcount(i) > 0 then
            l_won.extend;
            l_won(l_won.count) := l_cand(i);
         end if;
      end loop;

        -- Remaining READY headers (reads within this txn, excludes our claim)
      select count(distinct header_id)
        into p_remaining_headers
        from csg_so_details_gtm_tbl
       where oic_instance_id = p_instance_id
         and process_status = p_ready_status;

      if l_won.count = 0 then
            -- lost the race on every candidate this round
         p_picked_headers := 0;
         commit;
         return;
      end if;

        --  Start : assemble nested output
      l_prev_hdr := null;
      for r in c_data loop
         if l_prev_hdr is null
         or r.header_id <> l_prev_hdr then
            if l_idx > 0 then
               p_orders(l_idx).lines := l_lines;   -- flush prev header
            end if;
            p_orders.extend;
            l_idx := p_orders.count;
            p_orders(l_idx) := csg_so_header_obj(
               r.header_id,
               r.sourcesystem,
               r.ponumber,
               r.ordernumber,
               r.process_message,
               r.businessunit,
               r.creationdate,
               r.fnoauthcode,
               r.quotenum,
               r.shippinginstructions,
               r.fob,
               r.order_key,
               r.line_count,
               r.order_amount,
               r.shipto_cc,
               r.salesbu,
               r.oic_instance_id,
                    -- csg_so_party_obj(r.ATTRIBUTE[party-id], r.ultcg_account_num,
               csg_so_party_obj(
                  r.ultcg_party_id,
                  r.ultcg_account_num,
                  r.ultcg_address1,
                  r.ultcg_city,
                  r.ultcg_country
               ),
               csg_so_party_obj(
                  r.billto_party_id,
                  r.billt_account_num,
                  r.billt_address1,
                  r.billt_city,
                  r.billt_country
               ),
               csg_so_party_obj(
                  r.shipto_party_id,
                  r.shipt_account_num,
                  r.shipt_address1,
                  r.shipt_city,
                  r.shipt_country
               ),
               csg_so_party_obj(
                  r.export_party_id,
                  null,
                  null,
                  null,
                  null
               ),
               csg_so_party_obj(
                  r.delds_party_id,
                  r.delds_account_num,
                  null,
                  null,
                  null
               ),
               csg_so_party_obj(
                  r.bill_from_id,
                  null,
                  null,
                  null,
                  null
               ),
               csg_so_party_obj(
                  r.end_user_id,
                  null,
                  null,
                  null,
                  null
               ),
               csg_so_party_obj(
                  r.end_customer_id,
                  null,
                  null,
                  null,
                  null
               ),
               csg_so_party_obj(
                  r.legal_entity_id,
                  null,
                  null,
                  null,
                  null
               ),
               csg_so_party_obj(
                  r.ship_from_id,
                  null,
                  null,
                  null,
                  null
               ),
               csg_so_party_obj(
                  r.supplier_id,
                  null,
                  null,
                  null,
                  null
               ),
               csg_so_line_tbl()
            );

            l_lines := csg_so_line_tbl();
            l_prev_hdr := r.header_id;
         end if;

         l_lines.extend;
         l_lines(l_lines.count) := csg_so_line_obj(
            r.unit_list_price,
            r.line_type_code,
            r.order_type,
                -- r.display_line_number, r.line_number, r.ATTRIBUTE[inventory-item-id], r.item_desc,
            r.display_line_number,
            r.line_number,
            r.inventory_item_id,
            r.item_desc,
            r.sales_product_type,
            r.ordered_quantity,
            r.unit_selling_price,
            r.extended_amount,
            r.fulfill_line_id,
            r.root_parent_fulfill_line_id,
            r.productplant,
            r.inventory_organization_id,
            r.product_type,
            r.contract_start_date,
            r.contract_end_date,
            r.unit_quantity,
            r.service_duration,
            r.service_duration_period_code,
            r.sales_product_type_code,
            r.integrate_subscription_flag,
            r.ordered_uom,
            r.line_status,
            r.line_open_flag,
            r.on_hold,
            r.eccn,
            r.earus
         );
      end loop;

      if l_idx > 0 then
         p_orders(l_idx).lines := l_lines;   -- flush final header
      end if;
      p_picked_headers := l_won.count;
      commit;   -- make the claim durable (requires non-XA adapter datasource)

   exception
      when others then
         rollback;   -- failed pickup un-claims: nothing left IN-PROGRESS
         raise;      -- surface fault to OIC
   end pickup_so_details;


    ------------------------------------------------------------------
   procedure set_header_status (
      p_instance_id  in varchar2,
      p_header_id    in varchar2,
      p_status       in varchar2,
      p_message      in varchar2,
      p_rows_updated out number
   ) as
   begin
      update csg_so_details_gtm_tbl
         set process_status = p_status,
             process_message = p_message,
             last_update_date = sysdate
       where oic_instance_id = p_instance_id
         and header_id = p_header_id;

      p_rows_updated := sql%rowcount;
      commit;
   exception
      when others then
         rollback;
         raise;
   end set_header_status;


    ------------------------------------------------------------------
   procedure set_headers_status (
      p_instance_id  in varchar2,
      p_header_ids   in csg_hdr_id_tbl,
      p_status       in varchar2,
      p_message      in varchar2,
      p_rows_updated out number
   ) as
   begin
        --  Start : bulk chunk status advance
      if p_header_ids is null
      or p_header_ids.count = 0 then
         p_rows_updated := 0;
         return;
      end if;

      update csg_so_details_gtm_tbl
         set process_status = p_status,
             process_message = p_message,
             last_update_date = sysdate
       where oic_instance_id = p_instance_id
         and header_id in (
         select column_value
           from table ( p_header_ids )
      );

      p_rows_updated := sql%rowcount;
      commit;
        -- End
   exception
      when others then
         rollback;
         raise;
   end set_headers_status;

end csg_so_pickup_pkg;

create or replace type csg_so_header_tbl as
   table of csg_so_header_obj;

create or replace type csg_so_header_obj as object (
      header_id            varchar2(50),
      sourcesystem         varchar2(200),
      ponumber             varchar2(200),
      ordernumber          varchar2(200),
      status_code          varchar2(200),
      businessunit         varchar2(240),
      creationdate         date,
      fnoauthcode          varchar2(200),
      quotenum             varchar2(200),
      shippinginstructions varchar2(4000),
      fob                  varchar2(200),
      order_key            varchar2(200),
      line_count           varchar2(200),
      order_amount         varchar2(200),
      shipto_cc            varchar2(200),
      salesbu              varchar2(200),
      oic_instance_id      varchar2(200),
      ult_customer         csg_so_party_obj,
      bill_to              csg_so_party_obj,
      ship_to              csg_so_party_obj,
      export_party         csg_so_party_obj,
      deliver_to           csg_so_party_obj,
      bill_from            csg_so_party_obj,
      end_user             csg_so_party_obj,
      end_customer         csg_so_party_obj,
      legal_entity         csg_so_party_obj,
      ship_from            csg_so_party_obj,
      supplier             csg_so_party_obj,
      lines                csg_so_line_tbl
);
