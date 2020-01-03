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

//Define parameters to be populated through Excel data
float supplyInput[SupplyXYear] = ...;
float demandInput[DemandXYear] = ...;
float gencostInput[SupplyXDemandXTechnologyXYear] = ...;
float transcostInput[SupplyXDemandXTechnologyXYear] = ...;


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


//Calculate adjusted parameters and variables
dexpr float generationCost = 
  sum (s in SupplyCountry, d in DemandCountry, t in Technology, y in Year) (gencost[s][d][t][y] * quantity[s][d][t][y]) ;
  
dexpr float transmissionCost = 
  sum (s in SupplyCountry, d in DemandCountry, t in Technology, y in Year) (transcost[s][d][t][y] * quantity[s][d][t][y]) ;
  

//Define objective function
dexpr float cost = generationCost + transmissionCost;

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
           
           
//Minimum home energy production constraint: 50% own production by 2030
  //forall(d in DemandCountry)
    //ctImportLimit: sum(s in SupplyCountry : s==d, t in Technology : t != "ScaleCurrent") quantity[s][d][t]["2030"]
      //     >= demand[d]["2030"] * 0.5;
         
           
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

