USE [DWH]
GO
/****** Object:  StoredProcedure [dbo].[VisitasClientes4UM]    Script Date: 6/25/2020 2:49:57 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Carlos Toledo>
-- Create date: <2017-11-09>
-- Description:	<Carga de Maestro>
-- =============================================
--EXEC PROCEDURE [dbo].[VisitasClientes4UM];
CREATE PROCEDURE [dbo].[VisitasClientes4UM] @Ejecutivo decimal(10),@Visitado smallint, @Canal VARCHAR(10), @Plataforma VARCHAR(30)
AS					
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.

	--declare @Ejecutivo decimal(10),@Visitado smallint, @Canal VARCHAR(10), @Plataforma VARCHAR(30)
	--set @Ejecutivo = 11872570 
	--SET @Visitado = 0
	--SET @Canal = 'C&I'

	SET NOCOUNT ON;


	DECLARE @mesActividad int
	
	SELECT		@mesActividad	=	max(maestAct.Fecha)
	FROM		dbo.maestro_cli		maestAct

	DECLARE @fecha datetime;

	SELECT 
				CLIE.rut_cli
				,CLIE.nombre		cliente
				,EJECUT.rut_ejec	rut_ejec
				,EJECUT.nombre		nombre
				,JEFE.rut_ejec		rut_jefe	
				,JEFE.nombre		Jefe
				,PLATAF.descripcion	plataforma
				,Canal
				,VisitaCli.fechaFM
				,VisitaCli.fecha
				,CASE
				WHEN	CONVERT(VARCHAR(10),VisitaCli.fecha,112)	>= DATEADD (month,-CASE WHEN frec_visita is null then 4 else frec_visita END,CONVERT(VARCHAR(10), GETDATE(), 111))
				THEN	1--'VISITADO4M'
				ELSE	0--'NO VISITADO'
				END									'VISITADO'
				,moex.motivo
	FROM		[DWH].[dbo].[clientes]			CLIE	
	LEFT JOIN 	
	(
		SELECT 
				rut_cli
				,MAX(fechaFM)	fechaFM
				,MAX(fecha)		fecha
		FROM 
		(
			SELECT		
						CLIENT.rut_cli
						,fecha
						,EOMONTH(convert(varchar(10),fecha,112))	fechaFM
			FROM		[DWH].dbo.clientes	CLIENT
			LEFT JOIN	
			(
				select 
							MAX(VISITA.[fec_realizacion])	fecha
							,CLIENT.centro_decision
				from 		[DWH].dbo.visitas		VISITA
				LEFT JOIN	[DWH].dbo.clientes	CLIENT
				ON			VISITA.id_cliente = CLIENT.id
				WHERE		CLIENT.centro_decision IS NOT NULL
				GROUP BY	CLIENT.centro_decision
			)CLIVIS
			ON			CLIVIS.centro_decision = CLIENT.centro_decision
			WHERE		1=1
			--AND			EOMONTH(fecha) BETWEEN	CLIENT.[fec_desde]	AND	ISNULL(CLIENT.[fec_hasta],'29991231')

			AND			CLIVIS.centro_decision IS NOT NULL
		)Visita
		group by	rut_cli

	)VisitaCli				
	ON			VisitaCli.rut_cli	= CLIE.rut_cli

	LEFT JOIN 	[dwh].[dbo].[clientes_excluidos_vis]	CLIEXC
	on			CLIE.id	=	   CLIEXC.id_cliente

	LEFT JOIN 	[dwh].[dbo].[motivo_exclusion_vis]	moex
	on			moex.id	=	   CLIEXC.id_motivo

	LEFT JOIN 	[DWH].[dbo].[asignacion_clientes]	ascl
	ON			CLIE.id		=	ascl.id_cliente

	LEFT JOIN 	[DWH].[dbo].[ejecutivos]	EJECUT
	ON			ascl.id_ejecutivo		=	EJECUT.id		

	LEFT JOIN 	[DWH].[dbo].[jerarquia_ejecutivos]	jera
	ON			jera.id_ejecutivo		=	EJECUT.id

	LEFT JOIN 	[DWH].[dbo].[ejecutivos]	JEFE
	ON			jera.id_jefe		=	JEFE.id
	AND			JEFE.id_plataforma	IS NOT NULL

	LEFT JOIN 	[DWH].[dbo].[plataformas]	PLATAF
	ON			UPPER(CASE
				WHEN	JEFE.id_plataforma	IS NULL
				THEN	EJECUT.id_plataforma
				ELSE	JEFE.id_plataforma
				END)				=	PLATAF.id

	LEFT JOIN 	[DWH].[dbo].[canales]	Canal
	ON			Canal.id			=	PLATAF.id_canal


	LEFT JOIN	[DWH].dbo.maestro_cli	maestAct
	ON			maestAct.id_cliente	=	CLIE.id
	AND			maestAct.Fecha		=	@mesActividad--EOMONTH(DATEADD (month,-1,CONVERT(VARCHAR(10), GETDATE(), 111)))			

	where		1=1
	AND			CONVERT(VARCHAR(10), GETDATE(), 112) BETWEEN	CLIE.[fec_desde]	AND	ISNULL(CLIE.[fec_hasta],29991231)
	AND			CONVERT(VARCHAR(10), GETDATE(), 112) BETWEEN	EJECUT.[fec_desde]	AND	ISNULL(EJECUT.[fec_hasta],29991231)
	AND			CONVERT(VARCHAR(10), GETDATE(), 112) BETWEEN	PLATAF.[fec_desde]	AND	ISNULL(PLATAF.[fec_hasta],29991231)
	AND			maestAct.Activo = 1

	AND			Canal	<>	'OTRO'
	AND		(	CASE
				WHEN	CLIEXC.id_cliente	IS NOT NULL
					THEN	2
				WHEN	convert(varchar(10),ISNULL(VisitaCli.fecha,19000101),112)	>= DATEADD (month,-CASE WHEN frec_visita is null then 4 else frec_visita END,CONVERT(VARCHAR(10), GETDATE(), 111))
					THEN
						CASE	
							WHEN	@Visitado = 1 AND convert(varchar(10),ISNULL(VisitaCli.fecha,19000101),112)	>= DATEADD (month,-CASE WHEN frec_visita is null then CASE WHEN frec_visita is null then 4 else frec_visita END else frec_visita END,CONVERT(VARCHAR(10), GETDATE(), 111))
								THEN	1--'VISITADO4M'
							WHEN	@Visitado = 3 AND convert(varchar(10),ISNULL(VisitaCli.fecha,19000101),112)	BETWEEN EOMONTH(DATEADD (month,-CASE WHEN frec_visita is null then 4 else frec_visita END,CONVERT(VARCHAR(10), GETDATE(), 111))) AND EOMONTH(DATEADD (month,-3,CONVERT(VARCHAR(10), GETDATE(), 111)))
								THEN	3--'PORVENCER'					
						END
				WHEN	convert(varchar(10),ISNULL(VisitaCli.fecha,19000101),112)	< DATEADD (month,-CASE WHEN frec_visita is null then 4 else frec_visita END,CONVERT(VARCHAR(10), GETDATE(), 111))
					THEN	0--'NO VISITADO'
					else CASE WHEN frec_visita is null then 4 else frec_visita END--'TODOS NO EXCLUIDOS'
				END	=	@Visitado	OR (@Visitado = 4 and CLIEXC.id_cliente 	IS NULL) OR (@Visitado = 5))--5= TODOS incl EXCLUIDOS
	AND		(	Canal			=	@Canal		OR	@Canal = '')
	AND		(	EJECUT.rut_ejec	=	@Ejecutivo	OR	@Ejecutivo = 0)
	AND		(	PLATAF.descripcion	=	@Plataforma	OR	@Plataforma IS NULL)
	order by CLIE.rut_cli asc

END



GO
