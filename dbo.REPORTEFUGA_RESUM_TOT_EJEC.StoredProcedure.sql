USE [DWH]
GO
/****** Object:  StoredProcedure [dbo].[REPORTEFUGA_RESUM_TOT_EJEC]    Script Date: 6/25/2020 2:49:57 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Carlos Toledo>
-- Create date: <2017-11-09>
-- Description:	<REPORTE FUGA>
-- =============================================
--[dbo].[REPORTEFUGA_RESUM_TOT_EJEC] NULL, 'CORPORATIVA',NULL
CREATE PROCEDURE [dbo].[REPORTEFUGA_RESUM_TOT_EJEC]  @Canal varchar(30), @Plataforma Varchar(30), @rut_ejec int
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
				SELECT 
						tipo,
						'+@MesesTexto +'
				FROM	
				(
					SELECT 
							fecha	
							,case
							when	tipo = ''Ind_Fuga''	
							then	convert(numeric(8,1),convert(numeric(8,3),valor)*100)
							else	convert(numeric(8,1),valor) 
							end	valor	
							,tipo
							,case
							when	tipo = ''Fugado''	then	2
							when	tipo = ''Nuevo_Recup''	then	1
							when	tipo = ''Perdido''	then	3
							when	tipo = ''Activo''	then	4
							when	tipo = ''Ind_Fuga''	then	5
							when	tipo = ''Nuev_Fug''	then	6
							when	tipo = ''Ant_Indicador''	then	7
							end			orden
					FROM 	
					(
						-- Pivot table with one row and five columns
						SELECT	
								PivotTable.fecha
								,convert(float,ISNULL(PivotTable.[Nuevo_Recup],0))	[Nuevo_Recup]
								,convert(float,ISNULL(PivotTable.[Fugado],0))		[Fugado]
								,convert(float,ISNULL(PivotTable.[Perdido],0))		[Perdido]
								,convert(float,ISNULL(PivotTable.[Activo],0))		[Activo]
								,CASE 
									WHEN PivotTable.[Fugado]IS NULL OR PivotTable.[Fugado] = 0
										THEN 0
									ELSE	-CONVERT(FLOAT,PivotTable.[Nuevo_Recup])/CONVERT(FLOAT,PivotTable.[Fugado])
								END					Nuev_Fug
								,CASE 
									WHEN ISNULL(PivotTable.[Fugado],0)+ISNULL(PivotTable.[Perdido],0) = 0
										THEN 0
									ELSE	CONVERT(FLOAT,ISNULL(PivotTable.[Nuevo_Recup],0))/CONVERT(FLOAT,ISNULL(PivotTable.[Fugado],0)+ISNULL(PivotTable.[Perdido],0))
								END					Ant_Indicador
								,CASE 
									WHEN ISNULL(PivotTable2.[Activo],0) = 0
										THEN 0
									ELSE	(CONVERT(FLOAT,ISNULL(PivotTable.[Fugado],0))-CONVERT(FLOAT,ISNULL(PivotTable2.[Fugado],0)))/CONVERT(FLOAT,ISNULL(PivotTable2.[Activo],0))
								END					Ind_Fuga
						FROM
						(
							select	
										count(rut_cli)*valor		cantidad
										,fecha
										,subtipo
							from		dwh_stg.dbo.wrk_rep_fugados
							WHERE		fecha	> @fechaMin
							AND			plataforma NOT IN (''ESTRUCTURADOS'',''INMOBILIARIA'',''NORMALIZACION''
										,''PLATAFORMA EMPRESAS'')
							AND	(	@Plataforma	=	Plataforma	OR 	@Plataforma IS NULL)
							AND	(	@rut_ejec	=	rut_ejec	OR 	@rut_ejec IS NULL)
							AND	(	@Canal	=	canal	OR 	@Canal IS NULL)
							group by	
										fecha
										,subtipo
										,valor
						) AS SourceTable
						PIVOT
						(
							sum(cantidad)
							FOR subtipo IN ([Perdido],[Nuevo_Recup],[Fugado],[Activo])
						) AS PivotTable
						LEFT JOIN 
						(
							select	
										count(rut_cli)*valor		cantidad
										,fecha
										,subtipo
							from		dwh_stg.dbo.wrk_rep_fugados
							WHERE		fecha	> @fechaMin1
							AND			plataforma NOT IN (''ESTRUCTURADOS'',''INMOBILIARIA'',''NORMALIZACION''
										,''PLATAFORMA EMPRESAS'')
							AND	(	@Plataforma	=	Plataforma	OR 	@Plataforma IS NULL)
							AND	(	@rut_ejec	=	rut_ejec	OR 	@rut_ejec IS NULL)
							AND	(	@Canal	=	canal	OR 	@Canal IS NULL)
							group by	
										fecha
										,subtipo
										,valor
						) AS SourceTable
						PIVOT
						(
							sum(cantidad)
							FOR subtipo IN ([Perdido],[Nuevo_Recup],[Fugado],[Activo])
						) AS PivotTable2
						ON		PivotTable.fecha	=	convert(varchar(10),
															EOMONTH(dateadd(month,1,convert(varchar(10),PivotTable2.fecha,112)))
														,112)
					)A
					UNPIVOT
					   (
							valor FOR tipo IN 
							(Nuevo_Recup,Fugado,Perdido,Activo,Nuev_Fug,Ant_Indicador,Ind_Fuga)
					)AS unpvt
				)
				as T
				PIVOT 
				(
					MAX(valor)
					FOR Fecha IN (' + @Meses + ')
				) as P 
				order by orden
				'
		--SELECT @stmt
		SET @ParmDefinition = 
				N'
				@fechaMin	int, 
				@fechaMin1	int  
				,@Plataforma	varchar(30)  
				,@Canal		varchar(30)
				,@rut_ejec		int';  
		
		EXEC sp_executesql  @stmt = @stmt, @ParmDefinition = @ParmDefinition,  
							  @fechaMin = @fechaMin,  
							  @fechaMin1 = @fechaMin1
							  ,@Plataforma =	@Plataforma
							  ,@Canal=	@Canal
							  ,@rut_ejec=	@rut_ejec;

END


GO
