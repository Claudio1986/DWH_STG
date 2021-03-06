USE [DWH]
GO
/****** Object:  StoredProcedure [dbo].[REPORTEFUGA_RESUM]    Script Date: 6/25/2020 2:49:57 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Carlos Toledo>
-- Create date: <2017-11-09>
-- Description:	<REPORTE FUGA>
-- =============================================
--[dbo].[REPORTEFUGA_RESUM]
CREATE PROCEDURE [dbo].[REPORTEFUGA_RESUM]
AS					
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.

	SET NOCOUNT ON;

	DECLARE @SQLString		nvarchar(max),
			@ParmDefinition nvarchar(500) ,
			@fechaMinM1		int,
			@fechaMin		int,
			@fechaMin1		int,
			@fechaMax		int,
			@Meses			nVARCHAR(MAX),
			@MesesTexto		nVARCHAR(MAX),
			@stmt			nvarchar(max)

	SET		LANGUAGE Spanish;
	set		@fechaMinM1		=	convert(varchar(10),EOMONTH(dateadd(month,-12,dateadd(day,1,getdate()))),112)
	set		@fechaMin		=	convert(varchar(10),EOMONTH(dateadd(month,-13,dateadd(day,1,getdate()))),112)
	set		@fechaMin1		=	convert(varchar(10),EOMONTH(dateadd(month,-14,dateadd(day,1,getdate()))),112)
	set		@fechaMax		=	convert(varchar(10),EOMONTH(dateadd(month,-1,dateadd(day,1,getdate()))),112)

		select	
				@MesesTexto	=	
				COALESCE(@MesesTexto  + ', ', '') + 'ISNULL(['+CONVERT(varchar(10),FECHA,112)+ '],0) '''
				+
				--DATENAME(MONTH, FECHA)+' '+DATENAME(YEAR, FECHA)
				'ID'+convert(varchar(2),ROW_NUMBER() OVER(ORDER BY FECHA ASC),112)
				+''' '
				,
				@Meses	=	COALESCE(@Meses  + ', ', '') + + '['+CONVERT(varchar(10),FECHA,112)+ '] '
		FROM	DWH.DBO.maestro_cli	maes
		WHERE	FECHA BETWEEN @fechaMinM1	AND	@fechaMax
		GROUP BY FECHA
		ORDER BY FECHA asc


		SELECT @stmt = '
				SELECT 	canal,
						plataforma,
						subtipo,
						'+@MesesTexto +'
				FROM	
				(
					select	
								count(rut_cli)*valor		valor
								,fecha
								,subtipo
								,case
								when	subtipo = ''Fugado''	then	2
								when	subtipo = ''Nuevo_Recup''	then	1
								when	subtipo = ''Perdido''	then	3
								when	subtipo = ''Activo''	then	4
								end			orden
								,plataforma
								,canal
					from		dwh_stg.dbo.wrk_rep_fugados
					WHERE		fecha	>=	@fechaMin1
					group by	
								fecha
								,subtipo
								,valor
								,plataforma
								,canal
								,case
								when	subtipo = ''Fugado''	then	2
								when	subtipo = ''Nuevo_Recup''	then	1
								when	subtipo = ''Perdido''	then	3
								when	subtipo = ''Activo''	then	4
								end
				)
				as T
				PIVOT 
				(
					MAX(valor)
					FOR Fecha IN (' + @Meses + ')
				) as P 
				WHERE plataforma NOT IN (''ESTRUCTURADOS'',''INMOBILIARIA'',''NORMALIZACION''
				,''PLATAFORMA EMPRESAS'')
				order by plataforma,orden
				'


		SET @ParmDefinition = 
				N'
				@fechaMin1	int';  


		EXEC sp_executesql  @stmt = @stmt, @ParmDefinition = @ParmDefinition,  
							  @fechaMin1 = @fechaMin1;

END


GO
