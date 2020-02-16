clear all;
cum_pl = zeros(99,1);
cum_pl_all = zeros(99,5000);
[CODE,NAME]=xlsread('listzin.xls');

nperiod= input('Enter the RSI period ');
c=input('Below what RSI value 0-100, should you go long ');
p=input('Enter your tolerance percentage ');

for i = 1:99
%% Taking input    
    filename = sprintf('%d.csv',CODE(i)); % Create string for each file  
    fid = fopen(filename); 
    out = textscan(fid,'%u %s %f %f %f %f' , 'delimiter', ',');

    fclose(fid);

    date = datevec(out{2});
    AdjOpen = out{3};
    AdjHigh = out{4};
    AdjLow = out{5};
    AdjClose = out{6};


    R = indicators(AdjClose,'rsi',nperiod);

%% Develop a preliminary strategy based on the indicator 
% We will create a simple trading rule based on the RSI'
% The boundary condition for RSI shall be decided by the user

assert(0<=c<=50);
signal = zeros(size(AdjClose)); 

for k=2:numel(R)-1
    if R(k-1) >= 100-c 
    signal(k)=-1; % Sell (short)
    elseif R(k-1) <= c
    signal(k)= 1; % Buy  (long)
    end
end
%%
%   we define STATE for calculating returns
%   state continues to generate signal untill there is a change in signal

state = zeros(size(AdjClose));

%% Ensuring a Stop loss and a take profit

for x=3:numel(AdjClose)-1
% if selling 
if signal(x-1) == -1; 
 if AdjOpen(x-1) > AdjClose(x-2) + p/100*AdjClose(x-2) 
     % Exit today, if yesterday's opening price exceeded by a certain percentage 
     signal(x)=1; 
 end
 
 % if buying
elseif signal(x-1) == 1; 
  if AdjOpen(x-1) < AdjClose(x-2) - p/100*AdjClose(x-2)
     % Exit today, if yesterday's opening price was lesser by a certain percentage
      signal(x)=-1;
  end
end
end

%% take profit
for x=2:numel(AdjClose)-1
% If selling
if signal(x-1) == -1;
    if R(x-1) <= R(x)-10
        % Will buy if RSI drops by 10
        signal(x) = 1;
    end
% If buying
elseif signal(x-1) == 1;
    if R(x-1) >= R(x)+10  
       % Will sell if RSI increases by 10
       signal(x) = -1;
    end
end
end
 
slipp=0.01;
cost=0.1;
%%
% To make sure that state continues to generate signal 
for k = 2:numel(state)-1
    if signal(k) == 1 || signal(k-1)== 1
            state(k) = 1;
        elseif signal(k) == -1 && state(k-1) == 1
            state(k)= 0;
        elseif signal(k)== -1 && state(k-1) == 0
            state(k) = -1;
    end
end     
%--------------------------------------------------------------------------

    ret = [0; state(1:end-1).*diff(AdjClose)-abs(diff(state))*cost/2*slipp];
    cumret = cumsum (ret);
    
    dailypnl = [0; state(1:end-1).*(diff(AdjClose)-abs(diff(state))*cost/2*slipp)./AdjClose(1:end-1)];
    dailypnl=dailypnl*100; %daily percentage pnl
    pl = cumsum(dailypnl); %cumulative sum
    cum_pl_all(i,1:size(AdjClose))= pl; %cumulative pnl for all companies on all days 
    cum_pl(i,1) = pl(end); %cumulative final day pnl for all companies


end

net_daily_pnl = mean (cum_pl_all); %avg of sum of pnl of all 100 companies on all 5000 days 
xlswrite('pnl.xls',cum_pl,'Sheet1','C1');   