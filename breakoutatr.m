clear all;
%% This code uses two functions slidefunc and indicators for a
%  moving window and ATR indicator, respectively.

%% Input and preprocessing
  n=input('Will buy if closing price goes above "n" days high, Enter n '); % n days 
  m=input('Will sell if closing price goes below a traling "m" day low, Enter m '); % m days
  
  % ATR_Length = input('ATR_Length'); % no. of days for the trailing atr
  % ATR_multiple = input('ATR_mutiple'); % multiple to ATR
  
  % Default
  ATR_Length = 20; 
  ATR_multiple = 5; 
  
  % has the company code of CNX midcap 100
  [CODE,NAME]=xlsread('listzin.xls');
  cum_pl = zeros(99,1);
  cum_pl_all = zeros(99,5000);

for i = 1:99
    
    filename = sprintf('%d.csv',CODE(i)); % Create string for each company filename  
    fid = fopen(filename); 
    out = textscan(fid,'%u %s %f %f %f %f' , 'delimiter', ',');

    fclose(fid);

    date = datevec(out{2});
    AdjOpen = out{3};
    AdjHigh = out{4};
    AdjLow = out{5};
    AdjClose = out{6};


    ATR_Length = 20; % no. of days for the trailing atr
    ATR_multiple = 5; % multiple to ATR
    
%% transaction slippage declarations
    s=size(AdjClose);
    slipp=0.01;
    cost=0.1;

%% sliding window and atr 
%  slidefunc-> runs a function(example max/min) on a sliding window of m/n 
%  days, in given direction(backward/forward/middle)
%  Please check the function's code for author's notes!

    movhigh=slidefunc(@max,n,AdjHigh,'backward');
    movLow=slidefunc(@min,m,AdjLow,'backward');

%  gives the 'ATR_Length' day atr
    out = indicators([AdjHigh,AdjLow,AdjClose],'atr',ATR_Length); 

%% n day high entry & trailing m day low Exit
    signal = zeros(size(AdjClose));
    state = zeros(size(AdjClose));
    
    for j=3:numel(AdjClose)-1
        if AdjClose(j-1) > movhigh(j-2) 
            % will buy today when yesterday's closing broke n day high
            signal(j) = 1;
        end
        if AdjClose(j) <  movLow (j-1)
             % will Sell today when yesterday's closing broke a trailing m day low
            signal(j+1) = -1;
        end
    end
  

%% ATR Exit
    atrstop = zeros(size(AdjClose)); 

%  Using a multiple to determine exit point, 
%  subtracting from an all time (six month here) high.
    
    periodhigh = slidefunc(@max,120,AdjHigh,'backward');
    atrstop(2:end) = periodhigh(1:end-1) - ATR_multiple * out(1:end-1); 

%% Ensuring that we're staying put, when ATRexit is lower than nday low, ie, price droping
%  from n day low to ATR stop.
    
    for j=3:numel(AdjClose)-1
        if AdjClose(j-1) <= atrstop(j-2) 
        % Exit when yesterday's closing price fell below the ATR stop
            signal(j) = 0;
        end
        
        % When price dropping from n-day low to ATR, signal zero there.
        if movLow(j-1) > atrstop(j-1)
            if AdjClose(j-1) > atrstop(j-1) && AdjClose(j-1) < movLow(j-1)
                signal(j) = 0;
            end
        end
        
    end
    
%%
% signal to state
z=numel(state)-1;
   for k = 2:z
        if signal(k) == 1 || signal(k-1)== 1
            state(k) = 1;
        elseif signal(k) == -1 && state(k-1) == 1
            state(k)= 0;
        elseif signal(k)== -1 && state(k-1) == 0
            state(k) = -1;
        end
   end
   
%% PnL Calculation
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
%display(pl);