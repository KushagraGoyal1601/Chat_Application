-module(messenger).
-export([start_server/0, server/2, logon/1, logoff/0, message/2, client/2, list_length/1, message_all/1, message_store/3, show_messages/2, loop/3, lp/2, show_userlist/2, get_userlist/0, get_UserList/0, get_MessageList/0]).



server_node() ->
   kushagra@kushagra.          %% System name on which code is running   



server(UserList, MessageList) ->
    receive
        {From, logon, Name} ->
            NewUserList = server_logon(From, Name, UserList),
            show_messages(From, MessageList),
            server_loopx(From, "joined the chat", NewUserList, NewUserList),
            server(NewUserList, MessageList);
        {From, logoff} ->
            NewUserList = server_logoff(From, UserList),
            server_loopx(From, "left the chat", UserList, UserList),
            server(NewUserList, MessageList);
        {From,message_to, To, Message} ->
            io:format("Private Message from ~p: ~p~n", [From, Message]),
            server_transferp(From, To, Message, UserList),
            io:format("list is now: ~p~n", [UserList]),
            server(UserList, MessageList);
        {From, get_userlist} ->
            show_userlist(From, UserList),
            server(UserList, MessageList);
        {get_UserList} ->
            io:format("list is now: ~p~n", [UserList]),
            server(UserList, MessageList);  
        {get_MessageList} ->
            io:format("Chat history is now: ~p~n", [MessageList]),
            server(UserList, MessageList);            
        {From,message_all, Message} ->
            io:format("Public Message from ~p: ~p~n", [From, Message]),
            server_loop(From, Message, UserList, UserList),
            io:format("list is now: ~p~n", [UserList]),
            NewMessageList = message_store({From, Message}, MessageList, UserList),
            io:format("messagelist is now: ~p~n", [NewMessageList]),
            server(UserList, NewMessageList)     
    end.
message_store({From, Message}, MessageList, UserList) ->
    {value, {From, Name}} = lists:keysearch(From, 1, UserList),
    Timestamp = calendar:local_time(),
    Messagelist = update_message(Name, Message, Timestamp, MessageList),
    Messagelist.


update_message(Name, Message, Timestamp, [H|T])        -> [{Name, Message, Timestamp}, H |T];
update_message(Name, Message, Timestamp, [])           -> [{Name,Message,Timestamp}].

show_userlist(From, UserList) ->
    lp(From, UserList).
    
lp(_From, []) ->
    ok;
lp(From, UserList) ->
    [H|T] = UserList,
    From ! {H},
    lp(From, T).  


    
show_messages(From, MessageList) ->
    loop(From, MessageList, 5).
    
loop(_From, _MessageList, 0) ->
     ok;
loop(_From, [], _N) ->
     ok;
loop(From, MessageList, N) ->
     [H|T] = MessageList,
     From ! {H}, 
     loop(From, T, N-1).
              
start_server() ->
    register(messenger6, spawn(messenger6, server, [[], []])).
    
get_UserList() ->
    {messenger6, kushagra@kushagra } ! { get_UserList}.  
    
get_MessageList() ->
    {messenger6, kushagra@kushagra} ! { get_MessageList}. 
       
list_length([]) ->
    0;    
list_length([_| Rest]) ->
    1 + list_length(Rest).    



server_logon(From, Name, UserList) ->
     Len = 1 + list_length(UserList),
    if 
        Len =< 4 ->
            case lists:keymember(Name, 2, UserList) of
            true ->
                From ! {messenger6, stop, user_exists_at_other_node},  
                UserList;
            false ->
                From ! {messenger6, logged_on},
                [{From, Name} | UserList] 
            end;      
        Len > 4 ->
             io:fwrite("Room is full\n"),
             UserList
     end.  
          
    
    


server_logoff(From, UserList) ->
    lists:keydelete(From, 1, UserList).


server_loopx(_From, _Message, _UserList, []) ->
  ok;
server_loopx(From, Message, UserList, Userlist) ->
  [H|T] = Userlist,
  {A,To} = H,
  if 
    From == A ->
      server_loopx(From, Message, UserList, T);
    true ->
      server_transferx(From, To, Message, UserList),
      server_loopx(From, Message, UserList, T)
  end.        
    
server_loop(_From, _Message, _UserList, []) ->
  ok;
server_loop(From, Message, UserList, Userlist) ->
  [H|T] = Userlist,
  {A,To} = H,
  if 
    From == A ->
      server_loop(From, Message, UserList, T);
    true ->
      server_transfer(From, To, Message, UserList),
      server_loop(From, Message, UserList, T)
  end.        

server_transfer(From, To, Message, UserList) ->
    
    case lists:keysearch(From, 1, UserList) of
        false ->
            From ! {messenger6, stop, you_are_not_logged_on};
        {value, {From, Name}} ->
            server_transfer(From, Name, To, Message, UserList)
    end.

server_transfer(From, Name, To, Message, UserList) ->

    case lists:keysearch(To, 2, UserList) of
        false ->
            From ! {messenger6, receiver_not_found};
        {value, {ToPid, To}} ->
            ToPid ! {message_from, Name, Message}, 
            From ! {messenger6, sent} 
    end.

server_transferx(From, To, Message, UserList) ->
    
    case lists:keysearch(From, 1, UserList) of
        false ->
            From ! {messenger6, stop, you_are_not_logged_on};
        {value, {From, Name}} ->
            server_transferx(From, Name, To, Message, UserList)
    end.

server_transferx(From, Name, To, Message, UserList) ->

    case lists:keysearch(To, 2, UserList) of
        false ->
            From ! {messenger6, receiver_not_found};
        {value, {ToPid, To}} ->
            ToPid ! { Name, Message}
             
    end.
server_transferp(From, To, Message, UserList) ->
    
    case lists:keysearch(From, 1, UserList) of
        false ->
            From ! {messenger6, stop, you_are_not_logged_on};
        {value, {From, Name}} ->
            server_transferp(From, Name, To, Message, UserList)
    end.

server_transferp(From, Name, To, Message, UserList) ->

    case lists:keysearch(To, 2, UserList) of
        false ->
            From ! {messenger6, receiver_not_found};
        {value, {ToPid, To}} ->
            ToPid ! {message_fromp, Name, Message}, 
            From ! {messenger6, sent} 
    end.

logon(Name) ->
    case whereis(mess_client) of 
        undefined ->
            register(mess_client, 
                     spawn(messenger6, client, [server_node(), Name]));
        _ -> already_logged_on
    end.

logoff() ->
    mess_client ! logoff.
    

  
message_all(Message) ->
    case whereis(mess_client) of 
        undefined ->
            not_logged_on;
        _ -> mess_client ! {message_all, Message},
             ok
end.
    	    

message(ToName, Message) ->
    case whereis(mess_client) of 
        undefined ->
            not_logged_on;
        _ -> mess_client ! {message_to, ToName, Message},
             ok
end.
get_userlist() ->
   mess_client ! get_userlist.

client(ServerNode, Name) ->
    {messenger6, ServerNode} ! {self(), logon, Name},
    await_result(),
    client(ServerNode).

client(ServerNode) ->
    receive
        logoff ->
            {messenger6, ServerNode} ! {self(), logoff},
            exit(normal);
         get_userlist ->
            {messenger6, ServerNode} ! {self(), get_userlist};  
        {message_to, ToName, Message} ->
              io:format("Private Message To ~p: ~p~n", [ToName, Message]),
            {messenger6, ServerNode} ! {self(), message_to, ToName, Message},
            await_result();
        {message_all, Message} ->
            io:format("Message To All : ~p~n", [Message]),
            {messenger6, ServerNode} ! {self(), message_all, Message},
            await_result(); 
        {H} ->
            io:format(" ~p~n", [H]);
        {Name, Message} ->
            io:format(" ~p ~p~n", [Name, Message]);
        {message_fromp, FromName, Message} ->
            io:format(" Private Message from ~p: ~p~n", [FromName, Message]);
        {message_from, FromName, Message} ->
            io:format(" Message from ~p: ~p~n", [FromName, Message])
       
    end,
    client(ServerNode).


await_result() ->
    receive
        {messenger6, stop, Why} -> 
            io:format("~p~n", [Why]),
            exit(normal);
        {messenger6, What} ->  
            io:format("~p~n", [What])
    end.
