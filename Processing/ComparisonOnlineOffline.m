%% Code to generate comparisons between Online Sleep scoring results and offline
close all
figure;
%%%Load Online scoring results
load('sleepstage.mat');
%%%Load Offline scoring results
load('SleepScoring_OBGamma.mat');

allresult(:,2)=ceil(allresult(:,2)/20000);
TotRecordingTimeOnline=allresult(end,1)-allresult(1,1);
TotRecordingTimeOffline=tot_length(union(REMEpoch,SWSEpoch,Wake))/10^4;


%Find Gamma Threshold
subplot(5,2,10)
hold on
[Y,X]=hist(log10(allresult(:,3)),100);
Y=Y/sum(Y);
plot(X,Y)
[cf2,goodness2]=createFit2gauss(X,Y,[]);
a= coeffvalues(cf2);
b=intersect_gaussians(a(2), a(5), a(3), a(6));
gamma_thresh=b(find(b>a(2)&b<a(5)));

[Yoffline,Xoffline] = hist(log10(Data(SmoothGamma)),100);
Yoffline = Yoffline/sum(Yoffline);
plot(Xoffline,Yoffline)
title('Gamma Distribution');
legend('Online', 'Offline');
xlabel('Power (log)');
ylabel('Occurences (norm.');

if isempty(gamma_thresh) %Manual gamma selection if fit didnt work
    figure
    plot(X,Y);
    title('Choose Gamma threshold');
    [gamma_thresh, ~]=ginput(1);
    close;
end
% Find ThetaDelta Threshold
subplot(5,2,8)
hold on
[Y,X] = hist(log10(allresult(allresult(:,3)<10^gamma_thresh,6)),100);
Y = Y/sum(Y);
plot(X,Y)
%fit 
[cf2, ~, output] = createFit1gauss(X,Y);
a = coeffvalues(cf2);
theta_thresh = find(abs((output.residuals)'./Y)>0.5);
lim = find(X>a(2), 1, 'first');
theta_thresh = X(theta_thresh(find(theta_thresh>lim, 1, 'first')));
[Y,X] = hist(log10(Data(SmoothTheta)),100);
Y = Y/sum(Y);
plot(X,Y)
title('Theta/Delta Distribution');
legend('Online', 'Offline');
xlabel('Ratio theta/delta (log)');
ylabel('Occurences (norm.');
allresult=updateResults(allresult,gamma_thresh,theta_thresh);

%Construct Wake interval for Online
wake_index=find(allresult(:,8)==3);
wake_index=testEndIndex(wake_index,allresult);
wakeInt=intervalSet(allresult(wake_index,1)*10^4,allresult(wake_index+1,1)*10^4);
wakeInt=mergeCloseIntervals(wakeInt,3*10^4);
wakeInt=dropShortIntervals(wakeInt, 2.99*1e4);

%Construct REM interval for Online
REM_index=find(allresult(:,8)==2);
REM_index=testEndIndex(REM_index,allresult);
REMInt=intervalSet(allresult(REM_index,1)*10^4,allresult(REM_index+1,1)*10^4);
REMInt=mergeCloseIntervals(REMInt,3*10^4);
REMInt=dropShortIntervals(REMInt, 2.99*1e4);


%Construct NREM interval for Online
NREM_index=find(allresult(:,8)==1);
NREM_index=testEndIndex(NREM_index,allresult);
NREMInt=intervalSet(allresult(NREM_index,1)*10^4,allresult(NREM_index+1,1)*10^4);
NREMInt=mergeCloseIntervals(NREMInt,3*10^4);
NREMInt=dropShortIntervals(NREMInt, 2.99*1e4);




%Time comparison
%%Create vector from offline data
timeVector=zeros(TotRecordingTimeOnline,1);
wakeTimes=[floor(Start(Wake)/10^4) ceil(End(Wake)/10^4)]+1;
for i=1:size(wakeTimes,1)
    timeVector(wakeTimes(i,1):wakeTimes(i,2))=3;
end
REMTimes=[floor(Start(REMEpoch)/10^4) ceil(End(REMEpoch)/10^4)]+1;
for i=1:size(REMTimes,1)
    timeVector(REMTimes(i,1):REMTimes(i,2))=2;
end
SWSTimes=[floor(Start(SWSEpoch)/10^4) ceil(End(SWSEpoch)/10^4)]+1;
for i=1:size(SWSTimes,1)
    timeVector(SWSTimes(i,1):SWSTimes(i,2))=1;
end
%%
%%create vector from online data
%First step: Get rid of data where thresholds are not set
onlineVector=interp1(allresult(:,1),allresult(:,8),allresult(1,1):allresult(end,1),'next');
OnlineNotWorking=find(onlineVector<0);
if ~isempty(OnlineNotWorking) %% Test if online scoring was on from the beginning of the recording 
    startOnline=OnlineNotWorking(end)+1;
else
    startOnline=1;
end
onlineVector=onlineVector(startOnline:end);
timeVector=timeVector(startOnline:end);
%Synchronise the recordings by Xcorrelation on the wake states
WakeTimeVector=timeVector;
WakeTimeVector(WakeTimeVector<3)=0;
WakeOnlineVector=onlineVector;
WakeOnlineVector(WakeOnlineVector<3)=0;
[r,lags]=xcorr(WakeTimeVector,WakeOnlineVector);
subplot(5,2,[7 9])
plot(lags,abs(r));
[~,i]=max(r);
lag=lags(i);
title(strcat('Cross-correlation: lag=',num2str(lag/length(onlineVector))));
xlim([-500,500]);
xlabel('Time (s)');

subplot(5,2,[5 6]);hold on
plot(timeVector)
plot((1:length(onlineVector))+lag,onlineVector)
xlabel('Time (s)');
yticks([1 2 3])
yticklabels({'NREM','REM','Wake'})
ylim([-1 4]);
legend('Offline','Online');

%Evaluate classifier performance
Kappa = mKAPPA([timeVector(1+lag:length(onlineVector)+lag), onlineVector(:)]);
cp=classperf(timeVector(1+lag:length(onlineVector)+lag), onlineVector(:));
title(strcat('Adjusted Hypnogram: Kappa=',num2str(Kappa)));
accuracy=cp.CorrectRate*100
sensitivity=cp.Sensitivity*100
specificity=cp.Specificity*100
PPV=cp.PositivePredictiveValue*100
NPV=cp.NegativePredictiveValue*100

recallP = sensitivity;
recallN = specificity;
precisionP = PPV;
precisionN = NPV;
f1P = 2*((precisionP*recallP)/(precisionP + recallP));
f1N = 2*((precisionN*recallN)/(precisionN + recallN));
fscore = ((f1P+f1N)/2);
set(gcf,'Position',get(0,'Screensize'));
saveas(gcf, 'SleepScoringOfflineVsOnline.png', 'png');

%Confusion Matrix

confMatrix=flipud([tot_length(intersect(NREMInt,Wake)) tot_length(intersect(REMInt,Wake)) tot_length(intersect(wakeInt,Wake));
   tot_length(intersect(NREMInt,REMEpoch)) tot_length(intersect(REMInt,REMEpoch)) tot_length(intersect(wakeInt,REMEpoch));
   tot_length(intersect(NREMInt,SWSEpoch)) tot_length(intersect(REMInt,SWSEpoch))  tot_length(intersect(wakeInt,SWSEpoch))]);

confMatrix=confMatrix./sum(confMatrix,1);
subplot(5,2,[1 2 3 4])
totTimeOffline=sum(confMatrix,1);
totTimeOnline=sum(confMatrix,2);
h=heatmap({ strcat('Wake'), strcat('REM'),strcat('NREM')},{strcat('Wake'), strcat('REM'), strcat('NREM')},confMatrix);
h.XLabel=strcat('Online');
h.YLabel=strcat('Offline');
h.Title=strcat('Confusion matrix, Kappa=',num2str(Kappa));
h.ColorbarVisible='off';
balancedAccuracy=sum(diag(confMatrix))/3;

resultsTable=readtable('../../resultsUnsynched.csv','Delimiter', ',', 'HeaderLines', 0, 'ReadVariableNames', true, 'Format', '%s%f%f%f%f%f%f');
pwDir=strsplit(pwd,'\');
newResults={pwDir(end-1),Kappa,balancedAccuracy,accuracy,sensitivity,specificity,lag/length(onlineVector)};

if (~(ismember(pwDir(end-1),resultsTable{:,{'Date'}})))
    resultsTableUpdated=[resultsTable; newResults];
    writetable(resultsTableUpdated,'../../PostProcessing/resultsUnsynched.csv');
end