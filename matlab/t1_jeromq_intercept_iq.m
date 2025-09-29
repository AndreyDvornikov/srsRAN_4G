clearvars socket ...
          context ...
;

jenv('system');
javaaddpath('./thirdparty/jeromq/jeromq-0.6.0.jar');

import org.zeromq.*;

context_enb1_dl = ZContext();
context_enb1_ul = ZContext();

context_enb1_dl_buffer_size = 10; 
context_enb1_ul_buffer_size = 1;

context_enb1_dl_buffer = zeros(context_enb1_dl_buffer_size);
context_enb1_ul_buffer = zeros(context_enb1_ul_buffer_size);

% enb1 Params
enb1_fs = 20e9;


% socket  = context.createSocket(SocketType.PULL);
% socket.connect('tcp://localhost:2000');
% socket.setReceiveTimeOut(1000);

