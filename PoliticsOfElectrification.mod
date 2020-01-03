/*********************************************
 * OPL 12.6.3.0 Model
 * Author: Philipp Trotter, University of Bath
 * Creation Date: 14 Jul 2016 at 11:58:19
 *********************************************/

//Define sets
{string} SupplyInd = ...;
{string} DemandInd = ...;


//Define parameters
float supply[SupplyInd] = ...;
float supplyRed[SupplyInd] = ...;

/*
execute {
	for (var s in SupplyInd) {
	supplyRed[s] = supply[s] * 0.25;	
	}
}
*/

float demand[DemandInd] = ...;

float gencost[SupplyInd][DemandInd] = ...;
float transcost[SupplyInd][DemandInd] = ...;


//Define aux matrix
float matrix[SupplyInd][DemandInd] = ...;
float matrixinv[DemandInd][SupplyInd];
execute {
	for(var q in DemandInd) {
		for(var r in SupplyInd) {
			matrixinv[q][r] = matrix[r][q];				
		}	
	}
}



//Define decision variable
dvar float+ quantity[SupplyInd][DemandInd];


//Calculate adjusted parameters and variables
dexpr float generationCost = 
  sum (i in SupplyInd, j in DemandInd) (gencost[i][j] * quantity[i][j]) ;
  
dexpr float transmissionCost = 
  sum (i in SupplyInd, j in DemandInd) (transcost[i][j] * quantity[i][j]) ;


//Define objective function
dexpr float cost = generationCost + transmissionCost;

//Solve  
minimize cost;
  


//Define constraints 
subject to {
  // Satisfy demand 
  forall(j in DemandInd)
    ctDemand: sum(i in SupplyInd) matrix[i][j] * quantity[i][j]
           >= demand[j];

  // Dont exceed supply
  forall(i in SupplyInd)
    ctSupply: sum(j in DemandInd) matrixinv[j][i] * quantity[i][j]
           <= supplyRed[i];
           
}



//Post optimisation reporting
execute DISPLAY {
   for(var s in SupplyInd)
      for(var d in DemandInd)
      	if(quantity[s][d]==0)
      	{
        } else {      	      	
        writeln("transmit[",s,"][",d,"] = <",quantity[s][d],">");
        }        
}






 