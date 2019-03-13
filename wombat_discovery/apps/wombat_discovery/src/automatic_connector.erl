-module(automatic_connector).

-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_info/2, handle_call/3, handle_cast/2]).

-record(state, {discovery_config}).

start_link() ->
    Discovery_config = wombat_discovery_app:load_config(),
    State = #state{discovery_config = Discovery_config},
    gen_server:start_link({local, automatic_connector}, automatic_connector, State,[]).

init(_Args) ->
    self() ! start_discovery,
    {ok, _Args}.

handle_info(start_discovery, {State, no_conig}) ->
    io:format("No Wombat Discovery plugin configuration found. ~n"),
    {noreply,State};

handle_info(start_discovery, State) ->
    case State of
        {state,{MyNode,MyCookie,RetryCount,RetryWait}} -> 
            io:format("Connecting to Wombat node: ~p ~n", [MyNode]),
            do_discover(MyNode, MyCookie, RetryCount, RetryWait);
        Conf -> io:format("invalid config: ~p ~n",[Conf])
    end,
    {noreply, State};

handle_info({try_again, Count}, State) ->
    case Count of
        0 -> io:format("No Wombat Discovery plugin configuration found. ~n");
        _ -> {state,{Node, Cookie, _, Wait}} = State,
             do_discover(Node,Cookie,Count-1,Wait)
    end,
    {noreply, State};

handle_info(Msg,State) ->
    io:format("Hello automatic_connector handle_info: ~n ~p ~n ~p ~n",[Msg,State]),
    {noreply, State}.

handle_call(Msg, _From, State) ->
     io:format("Hello automatic_connector call ~n ~p ~n ~p ~n ~p ~n",[Msg,_From,State]),
    {reply, ok, State}.

handle_cast(Msg, State) ->
    io:format("Hello automatic_connector cast ~n ~p ~n ~p ~n", [Msg, State]),
    {noreply,State}.

do_discover(Node, Cookie, Count, Wait) ->
   io:format("Trying to connect to ~p ~n", [Node]),
    Reply = wombat_api:discover_me(Node, Cookie),
    case Reply of
      ok -> io:format("Node successfully added ~n");
      {error, already_added, Msg} -> io:format("Warning: ~p ~nStopping. ~n", [Msg]);
      {error, _Reason, Msg} -> io:format("Error: ~p ~nStopping. ~n", [Msg]);
      no_connection ->
      io:format("Wombat connection failed. Ensure the Wombat cookie is correct. ~nIf the node is already in Wombat, this may be OK. Retrying... ~n"),
      % timer:send_after({try_again, Count}, self(), 1) / erlang:send_after(1,self(),{try_again,Count}) / erlang:start_timer(1,self(),{try_again,Count})
      timer:sleep(Wait),
      self() ! {try_again, Count}
    end.


