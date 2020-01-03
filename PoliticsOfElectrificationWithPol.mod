/*********************************************
 * OPL 12.6.3.0 Model
 * Author: Philipp Trotter, University of Bath
 * Creation Date: 14 Jul 2016 at 11:58:19
 *********************************************/

//Define sets
{string} SupplyCountry = ...;
{string} DemandCountry = ...;
{string} Technology = ...;
{string} Year = ...;

range SupplyXYear = 1..1504;
range DemandXYear = 1..184;
range SupplyXDemandXTechnologyXYear = 1..69184;

float maxPotential2030 = ...;
float fossilRestriction = ...;
float maxPoliticalRisk = ...;


//Define parameters to be populated through Excel data
float supplyInput[SupplyXYear] = ...;
float demandInput[DemandXYear] = ...;
float gencostInput[SupplyXDemandXTechnologyXYear] = ...;
float transcostInput[SupplyXDemandXTechnologyXYear] = ...;
float demandTotal[Year] = ...;

float Instability[SupplyCountry] = ...;
float Corruption[SupplyCountry] = ...;
float InstitutionalIssues[SupplyCountry] = ...;
float EnergySecurity[DemandCountry] = ...;
float LandAccess[SupplyCountry] = ...;
float ExtSupplyCommitment[SupplyCountry] = ...;
float ExtDemandCommitment[DemandCountry] = ...;

//Convert Excel data to multi-dimensional CPLEX data
//Supply
float supply[SupplyCountry][Technology][Year];
int i = 1;
execute {
	for (var s in SupplyCountry) {
		for (var t in Technology) {
			for (var y in Year) {
				supply[s][t][y] = supplyInput[i];
				i = i + 1; 
			}		
		}
	}
}	


//Demand
float demand[DemandCountry][Year];
int j = 1;
execute {
	for (var d in DemandCountry) {
		for (var y in Year) {
			demand[d][y] = demandInput[j];
			j = j + 1; 
		}		
	}
}
	
	
//Cost data
float gencost[SupplyCountry][DemandCountry][Technology][Year];
float transcost[SupplyCountry][DemandCountry][Technology][Year];
int k = 1;
execute {
	for (var s in SupplyCountry) {
		for (var d in DemandCountry) {
			for (var t in Technology) {
				for (var y in Year) {			
				gencost[s][d][t][y] = gencostInput[k];
				transcost[s][d][t][y] = transcostInput[k];
				k = k + 1; 
  				}				
			}		
		}
	}
}	



//Impose restriction on maximum supply for all years
float maxPotSupply[SupplyCountry][Technology][Year];
execute {
	for (var s in SupplyCountry) {
		for (var t in Technology) {
			if(t == "Coal" || t == "NaturalGas" || t == "Oil"){		
			maxPotSupply[s][t]["2015"] = supply[s][t]["2015"] * maxPotential2030 * fossilRestriction * 0.25;
			maxPotSupply[s][t]["2020"] = supply[s][t]["2020"] * maxPotential2030 * fossilRestriction * 0.50;
			maxPotSupply[s][t]["2025"] = supply[s][t]["2025"] * maxPotential2030 * fossilRestriction * 0.75;
			maxPotSupply[s][t]["2030"] = supply[s][t]["2030"] * maxPotential2030 * fossilRestriction * 1.00; 		
			} else {
			maxPotSupply[s][t]["2015"] = supply[s][t]["2015"] * maxPotential2030 * 0.25;
			maxPotSupply[s][t]["2020"] = supply[s][t]["2020"] * maxPotential2030 * 0.50;
			maxPotSupply[s][t]["2025"] = supply[s][t]["2025"] * maxPotential2030 * 0.75;
			maxPotSupply[s][t]["2030"] = supply[s][t]["2030"] * maxPotential2030 * 1.00;
			}
		}		
	}
}





//Define decision variable
dvar float+ quantity[SupplyCountry][DemandCountry][Technology][Year];
dvar float+ PR1ExternalPressureSC[SupplyCountry];
dvar float+ PR1ExternalPressureDC[DemandCountry];
dvar float+ PR1ExternalPressure;
dvar float+ PR2EnergySecurityDC[DemandCountry];
dvar float+ PR2EnergySecurity;
dvar float+ PR3InstitutionalIssues;
dvar float+ PR3InstitutionalIssuesSC[SupplyCountry];
dvar float+ PR4Instability;
dvar float+ PR4InstabilitySC[SupplyCountry];
dvar float+ PR5Corruption;
dvar float+ PR5CorruptionSC[SupplyCountry];
dvar float+ PR6LandAccess;
dvar float+ PR6LandAccessSC[SupplyCountry];



//Calculate adjusted parameters and variables
dexpr float generationCost = 
  sum (s in SupplyCountry, d in DemandCountry, t in Technology, y in Year) (gencost[s][d][t][y] * quantity[s][d][t][y]) ;
  
dexpr float transmissionCost = 
  sum (s in SupplyCountry, d in DemandCountry, t in Technology, y in Year) (transcost[s][d][t][y] * quantity[s][d][t][y]) ;


//Define objective function
dexpr float cost = generationCost + transmissionCost + 0.001*(PR1ExternalPressure + PR2EnergySecurity + PR4Instability + PR3InstitutionalIssues + PR5Corruption + PR6LandAccess);


//Solve  
minimize cost;
  


//Define constraints 
subject to {
  // Satisfy demand in all countries during all time periods
  forall(d in DemandCountry, y in Year)
    ctDemand: sum(s in SupplyCountry, t in Technology : t != "ScaleCurrent") quantity[s][d][t][y]
           >= demand[d][y];

/*ctDemand: sum(s in SupplyCountry, t in Technology : t != "ScaleCurrent" && t != "Coal" && t != "NaturalGas" && t != "Oil") quantity[s][d][t][y]
           >= demand[d][y];*/



  // Dont exceed supply, assuming 25% more of maximal Potential can be brought online within 5 years
  forall(s in SupplyCountry, t in Technology, y in Year)
    ctSupply: sum(d in DemandCountry) quantity[s][d][t][y]
            <= maxPotSupply[s][t][y];       


  // Use infrastructure built in former time periods
  forall(s in SupplyCountry, t in Technology)
    ctInfrastructure1: sum(d in DemandCountry) quantity[s][d][t]["2020"]
    		>= sum(d in DemandCountry) quantity[s][d][t]["2015"];     
           
  forall(s in SupplyCountry, t in Technology)
    ctInfrastructure2: sum(d in DemandCountry) quantity[s][d][t]["2025"]
    		>= sum(d in DemandCountry) quantity[s][d][t]["2020"];    
  
  forall(s in SupplyCountry, t in Technology)
    ctInfrastructure3: sum(d in DemandCountry) quantity[s][d][t]["2030"]
    		>= sum(d in DemandCountry) quantity[s][d][t]["2025"]; 
           
  
  //Political constraints
  //Calculate risk 1: External pressure
  forall(s in SupplyCountry)
    ctPR1Suppy: PR1ExternalPressureSC[s]
    		>= 100 * ((ExtSupplyCommitment[s] + 0.01) - (sum(d in DemandCountry, t in Technology : t != "ScaleCurrent" && t != "Coal" && t != "NaturalGas" && t != "Oil") quantity[s][d][t]["2030"])) / (ExtSupplyCommitment[s]  + 1);
  
  forall(d in DemandCountry)
    ctPR1Demand: PR1ExternalPressureDC[d]
    		>= 100 * (ExtDemandCommitment[d] - (sum(s in SupplyCountry, t in Technology : t != "ScaleCurrent" && t != "Coal" && t != "NaturalGas" && t != "Oil") quantity[s][d][t]["2030"])) / (ExtDemandCommitment[d] + 1);

  PR1ExternalPressure 
  		== ((sum(s in SupplyCountry) PR1ExternalPressureSC[s]) + (sum(d in DemandCountry) PR1ExternalPressureDC[d])) / 47; 
    
  
  //Calculate risk 2: National energy security 
  forall(d in DemandCountry)
	ctPR2Demand: PR2EnergySecurityDC[d]  
 			>= 100 * (EnergySecurity[d] * demand[d]["2030"] - (sum(s in SupplyCountry : s == d, t in Technology) quantity[s][d][t]["2030"])) / (EnergySecurity[d] * demand[d]["2030"]);

  PR2EnergySecurity
		== (sum(d in DemandCountry) PR2EnergySecurityDC[d])  / 46;
	
	
  //Calculate risk 3: Institutional issues
  forall(s in SupplyCountry)
    PR3InstitutionalIssuesSC[s] == InstitutionalIssues[s] * (sum(d in DemandCountry : d != s, t in Technology) quantity[s][d][t]["2030"]);
  
  PR3InstitutionalIssues == (sum(s in SupplyCountry)  PR3InstitutionalIssuesSC[s]) / demandTotal["2030"];
  
  
  //Calculate risk 4: Political instability
  forall(s in SupplyCountry)
    PR4InstabilitySC[s] == Instability[s] * (sum(d in DemandCountry : d != s, t in Technology) quantity[s][d][t]["2030"]);
  
  PR4Instability == (sum(s in SupplyCountry) PR4InstabilitySC[s]) / demandTotal["2030"];
  
    
  //Calculate risk 5: Corruption
  forall(s in SupplyCountry)
    PR5CorruptionSC[s] == Corruption[s] * (sum(d in DemandCountry : d !=s , t in Technology) quantity[s][d][t]["2030"]);
  
  PR5Corruption == (sum(s in SupplyCountry) PR5CorruptionSC[s]) / demandTotal["2030"];
  

  //Calculate risk 6: Politicised land access 
  forall(s in SupplyCountry)
	ctPR6SupplySolar: PR6LandAccessSC[s]  
 			>= 100 * ((sum(d in DemandCountry, t in Technology : t=="Solar") quantity[s][d][t]["2030"]) - (LandAccess[s] * maxPotential2030 * supply[s]["Solar"]["2030"])) / (LandAccess[s] * maxPotential2030 * supply[s]["Solar"]["2030"] + 1);
  
  forall(s in SupplyCountry)
	ctPR6SupplyWind: PR6LandAccessSC[s]  
 			>= 100 * ((sum(d in DemandCountry, t in Technology : t=="Wind") quantity[s][d][t]["2030"]) - (LandAccess[s] * maxPotential2030 * supply[s]["Wind"]["2030"])) / (LandAccess[s] * maxPotential2030 * supply[s]["Wind"]["2030"] + 1);
  
  PR6LandAccess
		== (sum(s in SupplyCountry) PR6LandAccessSC[s])  / 47;
		
  
  //Maximum political risk of network constraint
  0.099*PR1ExternalPressure + 0.129*PR2EnergySecurity + 0.302*PR3InstitutionalIssues + 0.158*PR4Instability + 0.228*PR5Corruption + 0.084*PR6LandAccess 
  		<= maxPoliticalRisk;
  		
 // PR1ExternalPressure 
  //+ PR2EnergySecurity + PR3InstitutionalIssues + PR4Instability + PR5Corruption + PR6LandAccess) / 5 
  	//	<= maxPoliticalRisk;
 		
           
}




//Post estimation calculations for data export to Excel
float quantityLong[SupplyXDemandXTechnologyXYear];
int n = 1;
execute {
	for (var s in SupplyCountry) {
		for (var d in DemandCountry) {
			for (var t in Technology) {
				for (var y in Year) {			
				quantityLong[n] = quantity[s][d][t][y];
				n = n + 1; 
  				}				
			}		
		}
	}
}	


float supplyLong[SupplyXDemandXTechnologyXYear];
int q = 1;
execute {
	for (var s in SupplyCountry) {
		for (var d in DemandCountry) {
			for (var t in Technology) {
				for (var y in Year) {			
				supplyLong[q] = maxPotSupply[s][t][y];
				q = q + 1; 
  				}				
			}		
		}
	}
}

