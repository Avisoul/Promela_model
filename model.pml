		/*	 __    __        __      __   __   __  ___  __   __   __       	*/
		/*	/ _` |  /  |\/| /  \    |__) |__) /  \  |  /  \ /  ` /  \ |    	*/
		/*	\__> | /_  |  | \__/    |    |  \ \__/  |  \__/ \__, \__/ |___ 	*/
                                                               

mtype = {ready}

/* Reservation type */
typedef reservation {
	int requester;
}


 bit readyIsSent = false;

 bit helloIsSent = false;
 
 bool p2boolean = false; //not violated initially
 
 bool taskTerminated = false;
 
 bool p4boolean = false; //not violated initially
 

/* Capability strategy */
mtype = {sequence, concurrent};

/* Task type */
typedef task {
	mtype state;
	int id;
	mtype strategy;
};

/* Client Helo, Start Capability, 
	Capability Input/Output, Capability Complete */
mtype = {helo, c_start, c_in, c_out, c_done}

/* Response sent by capability (helo, i/o, etc.) */
typedef capabilityMessage {
	int taskId;
	pid capabilityId;
	mtype messageType;
};

/* Assume a maximum of capabilities to be 10 */
typedef capGlobalState {
	int hello[10];
	int start[10];
	int input[10];
	int output[10];
	int complete[10];
}

chan clientManagerReservation = [5] of {reservation};
chan managerClient = [5] of {task};
chan managerStrategyTask = [5] of {task};
chan capabilityClientHelo = [10] of {capabilityMessage};
chan startCapability[10] = [2] of {capabilityMessage};
chan capabilityInput[10] = [2] of {capabilityMessage};
chan capabilityOutput[10] = [2] of {capabilityMessage};
chan capabilityComplete[10] = [2] of {capabilityMessage};


byte task_cancel = 5;
byte task_complete = 0;
int amountOfCapabilitiesNeeded = 0;
capGlobalState capabilitiesState;

proctype Client() {
	reservation rsrv;
	rsrv.requester = _pid;

	atomic {
		//TODO: write random or leave as it is...
		do
			:: amountOfCapabilitiesNeeded = 1; break;
			:: amountOfCapabilitiesNeeded = 2; break;
			:: amountOfCapabilitiesNeeded = 3; break;
			:: amountOfCapabilitiesNeeded = 4; break;
			:: amountOfCapabilitiesNeeded = 5; break;
			:: amountOfCapabilitiesNeeded = 6; break;
			:: amountOfCapabilitiesNeeded = 7; break;
			:: amountOfCapabilitiesNeeded = 8; break;
			:: amountOfCapabilitiesNeeded = 9; break;
			:: amountOfCapabilitiesNeeded = 10; break;
		od;
	}

	clientManagerReservation ! rsrv;
	printf("~* Client %d had send a reservation for a task with capNum of %d *~\n", 
					_pid, amountOfCapabilitiesNeeded);

	if 
		::task_cancel == 0 ->
				taskTerminated = false;
				task readyTask;
				managerClient ? readyTask;
				printf("~* Ready task %d pid %d *~\n", readyTask.id, _pid);
				readyTask.state == ready && readyTask.id == _pid;
				printf("~* Task %d is ready *~\n", readyTask.id);
       			readyIsSent = true;
				
				int i;

				do
					::(i<amountOfCapabilitiesNeeded) -> {
						
						capabilityMessage message;
							capabilityClientHelo ? message;

							message.messageType == helo && message.taskId == _pid;
							capabilitiesState.hello[message.capabilityId] == 1;
							printf("~* Client %d was heloed by capability %d *~\n", _pid, message.capabilityId);

							helloIsSent = true;
		
						/* Send start and input to the capability */
							capabilityMessage startMsg;
							startMsg.capabilityId = message.capabilityId;
							startMsg.messageType = c_start;
							startMsg.taskId = _pid; 
							startCapability[startMsg.capabilityId] ! startMsg;
							capabilitiesState.start[startMsg.capabilityId] = 1;
							printf("Client %d sent start message to the capability %d!\n", _pid, startMsg.capabilityId);
						
							capabilityMessage inputMsg;
							inputMsg.messageType = c_in;
							inputMsg.taskId = _pid; 
							inputMsg.capabilityId = message.capabilityId; 
							capabilityInput[startMsg.capabilityId] ! inputMsg;
							capabilitiesState.input[inputMsg.capabilityId] = 1;
							printf("Client %d sent input message to the capability %d!\n", _pid, inputMsg.capabilityId);
						
						capabilityMessage outMessage;

						capabilityOutput[startMsg.capabilityId] ? outMessage;
						outMessage.messageType == c_out && outMessage.taskId == _pid;
						capabilitiesState.output[message.capabilityId] == 1;
						printf("Сapability %d sent output message to the client %d!\n", outMessage.capabilityId, _pid);
						
						capabilityComplete[startMsg.capabilityId] ? outMessage;
						outMessage.messageType == c_done && outMessage.taskId == _pid;
						capabilitiesState.complete[message.capabilityId] == 1;
						printf("Сapability %d sent complete message to the client %d! I = %d\n", outMessage.capabilityId, _pid, i);
					
						i++;
					}

					::(i==amountOfCapabilitiesNeeded) -> {
						printf("Task was complete! \n");
						task_complete = 1;
						//TODO: check if it was complete;
						break;
					}
				od;
	
		::task_cancel == 1 -> goto end;	
	fi;
	end: {
		taskTerminated = true;
		skip;
	}
}

proctype Manager() {
	reservation rsrv;
	clientManagerReservation ? rsrv;

	do
		:: task_cancel = 0; break;
		:: task_cancel = 1; break;
	od;

	if
		::task_cancel == 0 -> 
			task rsrvToTask;
			rsrvToTask.id = rsrv.requester; // setting up id
			rsrvToTask.state = ready;
			
			managerClient ! rsrvToTask;
			managerStrategyTask ! rsrvToTask;

		::task_cancel == 1 -> {
			printf("~* Task rejected *~\n");
			skip;
		}
	fi;
}

proctype Strategy() {

	if 
		::task_cancel == 1 -> goto endStrategy;
		::task_cancel == 0 -> goto continueStrategy;
	fi;

continueStrategy: {
	task strategyTask;
	managerStrategyTask ? strategyTask;

	do
		:: strategyTask.strategy = sequence; printf("~* Consequent strategy is in progress *~\n"); break;
		:: strategyTask.strategy = concurrent; printf("~* Concurrent strategy is in progress *~\n"); break;
	od;

	int i;

	do
		:: (i < amountOfCapabilitiesNeeded && strategyTask.strategy == concurrent) ->
				run Capability(strategyTask, i); 
				i = i + 1; 

		:: (i < amountOfCapabilitiesNeeded && strategyTask.strategy == sequence) ->
				run Capability(strategyTask, i);
				capabilitiesState.complete[i] == 1;
				i = i + 1;
 
		:: (i == amountOfCapabilitiesNeeded) -> break;
	od;
}
	endStrategy: skip;
}

proctype Capability(task capabilitytask; int i) {
	capabilityMessage message;

		message.taskId = capabilitytask.id;
		message.capabilityId = i;
		message.messageType = helo;
		capabilityClientHelo ! message;
		capabilitiesState.hello[i] = 1;
	

		// heloing the client (whatever it means)
		printf("~* Capability %d was assigned for task %d *~ \n", i, message.taskId);
		
	
		capabilityMessage startMessage;	
		startCapability[i] ? startMessage;
		startMessage.messageType == c_start && startMessage.taskId == capabilitytask.id;
		capabilitiesState.start[i] == 1;

		capabilityMessage inputMessage;
		capabilityInput[i] ? inputMessage;
		inputMessage.messageType == c_in && inputMessage.taskId == capabilitytask.id;
		capabilitiesState.input[i] == 1;
		
		message.messageType = c_out;
		message.taskId == capabilitytask.id;
		capabilityOutput[i] ! message;
		capabilitiesState.output[i] = 1;

		if 
			::((capabilitiesState.output[i] == 1)&& (capabilitiesState.start[i] == 0)) -> 
				p4boolean = true;			
				printf("~* p2 violated! *~\n");
			:: skip;
		fi;
		
		message.messageType = c_done;
		capabilityComplete[i] ! message;
		capabilitiesState.complete[i] = 1;
		
		if 
			::((capabilitiesState.complete[i] == 1)&& (capabilitiesState.output[i] == 0)) -> 
				p2boolean = true;			
				printf("~* p2 violated! *~\n");
			:: skip;
		fi;

}


init {
	run Client();
	run Manager();
	run Strategy();
}


ltl p0 { ((! ((helloIsSent==true))) U ((readyIsSent==true))) && ((! ((readyIsSent==true))) || (<> ((helloIsSent==true)))) }
ltl p2 { [](p2boolean == false) }

ltl p3 { []((task_cancel == 1 ) -> <> (taskTerminated==true)) }

ltl p4 { [](p4boolean == false) }
 /* 
 Capability output message is never sent before the Start Capability message.
 This property is significant for the system due to the clients can not expect any output message of the Capability before they get the message about the start of the Capability. 
 */