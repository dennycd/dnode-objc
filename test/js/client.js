#!/usr/bin/env node
var util = require('util');
var dnode = require('dnode');

//define a client dnode with specified interface
var client = dnode({
	hello : function(msg, cb){
		console.log("called from server with " + msg);
		cb("echo");
	}
});


//connect
client.connect("127.0.0.1", 8000, function(remote, conn){
	console.log("connected to remote");
	
	//remote interface ready 
    conn.on('ready', function(){
        console.log("conn (%s) remote interface ready", conn.id);
        console.log("remote interface " + util.inspect(remote));
        
        
        //call to server
        //remote.echo("greetings from client", function(msg){ console.log(msg);} );
    });

    //connection drops
    conn.on('end', function(){
        console.log("remote dropped for conn id " + conn.id);
    });
    
    
    //a bunch of error handling
    conn.on('error', function(err){
        console.log("forcing client drop due to dnode conn error " + util.inspect(err));
        conn.end();
    });

	conn.on('fail', function(){
		console.log("fail");
	});
	
    //broken pipe issue in older version of node js 
    conn.stream.on('error', function(err){
        console.log("forcing client drop due to conn stream error : " + util.inspect(err));
        conn.end();
    });
    
    
});
