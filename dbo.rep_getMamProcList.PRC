IF OBJECT_ID('dbo.rep_getMamProcList') IS NOT NULL
   DROP PROCEDURE [dbo].[rep_getMamProcList]
GO

SET ANSI_NULLS ON
 GO
SET QUOTED_IDENTIFIER ON
 GO
CREATE PROCEDURE [dbo].[rep_getMamProcList]

--Used by Procedure list Report

--15/01/2013 by Mishel - Add location parameter
(
	
	@DateFrom	NVARCHAR(20),
	@DateTo	NVARCHAR(20),
	@LocationID smallint
	--@ResourceGroupID 	SMALLINT = NULL
	
)

 AS

SET NOCOUNT ON

	DECLARE @SQL_TO smalldatetime
	DECLARE @SQL_FROM smalldatetime	
	
    SET @SQL_TO = DATEADD(d,1,@DateTo)
    SET @SQL_FROM = DATEADD(d,0,@DateFrom)

--"1/1/1900 12:00:00 AM"
----------------------------------------------------------------------------------------------
	--Create Temp tables 
----------------------------------------------------------------------------------------------
	

CREATE 	TABLE	#tmpMamEnc
(
	EncounterID		  int,
	PatientID		  int,
	DateScheduled     smalldatetime,
	PatientName       nvarChar(100),
	ProcDesc          nvarChar(100),
	MRN				  nvarChar(30),
	DateFollowUp      smalldatetime,
	Physician	      nvarChar(100),
	Radiologist	      nvarChar(100),
	Accession		  nvarChar(50),
	Assessment		  nvarChar(50),
	Recomendation	  nvarChar(50),
	ProcGroup			nvarChar(50),
	DateInterpretation  smalldatetime
)

BEGIN

IF @LocationID = -1
BEGIN
	INSERT INTO #tmpMamEnc (EncounterID, DateScheduled, PatientName, MRN, Radiologist,
	PatientID,Accession)
	select Enc.encounterId, Enc.DateScheduled, pat.LastName + ', ' + pat.FirstName, pat.MedicalRecordNo, 
	rad.LastName + ', ' + rad.FirstName,apt.PatientID,apt.ApptID
from Encounter as Enc
inner join Radiologist rad ON enc.RadiologistID = rad.RadiologistID
where (Enc.DateScheduled BETWEEN @SQL_FROM AND @SQL_TO) AND 
		(dbo.IsMammoProcedure(Enc.EncounterID)=1)
END
ELSE
BEGIN
	INSERT INTO #tmpMamEnc (EncounterID, DateScheduled, PatientName, MRN, Radiologist,PatientID,
	Accession)
	select Enc.encounterId, Enc.DateScheduled, pat.LastName + ', ' + pat.FirstName, pat.MedicalRecordNo, 
	rad.LastName + ', ' + rad.FirstName,apt.PatientID,apt.ApptID
from Encounter as Enc
inner join Appointment apt ON Enc.ApptID = apt.ApptID
inner join Patient pat ON apt.PatientID = pat.PatientID
inner join Radiologist rad ON enc.RadiologistID = rad.RadiologistID
where (Enc.DateScheduled BETWEEN @SQL_FROM AND @SQL_TO) AND 
		(dbo.IsMammoProcedure(Enc.EncounterID)=1) AND 
		pat.LocationID = @LocationID
END

update #tmpMamEnc set Physician = 
(select phy.LastName  + COALESCE(', ' +phy.FirstName,'') + COALESCE(' ' + phy.MiddleName, '')  + COALESCE(' ' + phy.SuffixID,'') 
from EncounterMammoData as emd 
inner join Encounter AS enc ON enc.EncounterID = #tmpMamEnc.EncounterID
inner join Appointment AS appt ON appt.ApptID = enc.ApptID 
inner join Physician AS phy ON phy.PhysicianID = appt.ReferringPhysicianID
where #tmpMamEnc.EncounterID = emd.encounterId)

update #tmpMamEnc set ProcDesc = (select  res.Resource + ' ; ' + cptT.CPTCode + ' -  ' +  cptT.CPT from Encounter as enc
inner join CPT as cptT ON enc.CPTID = cptT.CPTID
inner join Resource as res ON enc.ResourceID = res.ResourceID
where enc.EncounterID = #tmpMamEnc.EncounterID)

update #tmpMamEnc set Assessment = (select asm.AssessmentShort from EncounterMammoData as emd 
inner join MammoAssessment AS asm ON asm.AssessmentID = emd.assessmentId where #tmpMamEnc.EncounterID = emd.encounterId)

update #tmpMamEnc set Recomendation = (select mmr.RecommendationShort from EncounterMammoData as emd 
inner join MammoRecommendation AS mmr ON mmr.RecommendationID = emd.RecommendationID where #tmpMamEnc.EncounterID = emd.encounterId)

update #tmpMamEnc set DateFollowUp = (select emd.RecommendedFollowupDate from EncounterMammoData as emd 
where #tmpMamEnc.EncounterID = emd.encounterId)

update #tmpMamEnc set DateInterpretation = (select xEncSt.StepDate from EncounterMammoData as emd 
inner join Encounter enc ON enc.EncounterID = emd.encounterId
inner join xEncounterStep xEncSt ON xEncSt.StepID  = 11 AND enc.EncounterID = xEncSt.EncounterID
where #tmpMamEnc.EncounterID = emd.encounterId)

select * from #tmpMamEnc

drop 	TABLE	#tmpMamEnc

END

SET NOCOUNT OFF