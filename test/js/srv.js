#!/usr/bin/env node

var util = require('util');
var dnode = require('dnode');

//the service obj exposed to client 
var service = {
	echo : function(msg, cb){
		console.log("echo from client: " + msg);
		cb("hello from server");
	}
};

//the dnode server instance 
var server = dnode(function(client, conn){
	console.log("new conn " + conn.id);

	//remote interface ready 
    conn.on('ready', function(){
        console.log("conn (%s) remote interface ready", conn.id);
        console.log("remote interface " + util.inspect(client));
        
        //test call to client 
        client.hello("greeting from server", function(msg){console.log(msg);});
    });


    //connection drops
    conn.on('end', function(){
        console.log("client dropped for conn id " + conn.id);
    });
        




    //a bunch of error handling code 
	conn.on('remote', function(remote, d){
		console.log("remote has constructed its instance");
	});
	
	conn.on('local', function(ref, d){
		console.log("local instance constructed");
	});

	conn.on('fail', function(){
		console.log("fail");
	});

    //error occurs, we force connection drop 
    conn.on('error', function(err){
        console.log("forcing client drop due to dnode conn error " + util.inspect(err));
        conn.stream.end();
    });
    
    //broken pipe issue in older version of node js 
    conn.stream.on('error', function(err){
        console.log("forcing client drop due to conn stream error : " + util.inspect(err));
        conn.stream.end();
    });

	return service;
})




        
server.on('error', function(err){
    console.log("server error: " + util.inspect(err));
});  


server.listen(8000);
console.log("serving listening on 8000");