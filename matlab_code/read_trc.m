% Reading in file
addpath('matlab_code')
fileName = 'Recording_FX01_day_01_2-Unnamed.trc';
fid = fopen(fileName);

% Getting data from file
Rows = textscan(fid,'%s','delimiter','\n');
Rows2 = Rows{1}(7:end);
F = cell(1,length(Rows2));

% reorganizing data
for i = 1:length(Rows2)
    try
    tempRow = Rows2{i};
    t = textscan(tempRow,'%f','delimiter','\t','CollectOutput',1,'treatAsEmpty',{'VOID'});
    lt = length(t{1})-2;
    t2 = reshape(t{1}(3:end),[3 lt/3])';
    fid = find(~isnan(t2(:,1)));
    f2 = t2(fid,:);
    F{i} = f2;
    catch
    end
end

pixdM = 10; 
tic
[Fmerged, mergeN] = mergeTRC(F,pixdM);
toc


guessDist = [20.1706 31.6904 37.0356];

Fmn = zeros(size(Fmerged));

% graph
figure()
plot(Fmn)

for i =1:length(Fmerged)
    Fmn(i) = size(Fmerged{i},1);
end
n = length(Fmerged);
nMarkers = max(Fmn);

markers = nan(n,3,nMarkers);
for i = 1:n
    markers(i,:,1:Fmn(i)) = Fmerged{i}';
end



tpix = 5; tpixd = 3000; tpixH = 10;
combed = nan(size(markers)); combed(1,:,:) = markers(1,:,:);
dd = nan(n,nMarkers);
for i = 2:n
    if rem(i,60*300)==0
        fprintf(1,['Processing points for t = ' num2str(i/300) '\n']);
    end
    
    ctemp = nan(nMarkers,3);
    f1 = squeeze(combed(i-1,:,:))';
    f2 = squeeze(markers(i,:,:))';
    [id, id2] = knnsearch(f2,f1);
    ud1 = find(id2<tpix); %id for m1
    ud = id(find(id2<tpix)); %id for m2
    
    [~, s2, ~] = unique(ud,'first');
    ud = ud(s2); ud1 = ud1(s2);
    left2 = setdiff(1:nMarkers,ud);
    left1 = setdiff(1:nMarkers,ud1);
    ctemp(ud1,:) = f2(ud,:);
    left2m = f2(left2,:);
    
    if sum(~isnan(left2m(:,1)))>0
        numBnew = sum(~isnan(left2m(:,1)));
        numNnew = sum(isnan(left2m(:,1)));
        
        % update fmem
        newmid = find(~isnan(left2m(:,1)));
        left2mnew = left2m(newmid,:); lmnidreal = left2(newmid);
        
        fmem = nan(length(left1),3);
        fmtime = nan(length(left1),1);
        if i > tpixd
            tpd = tpixd;
        else
            tpd = i-1;
        end
        checkn = combed(((i-tpd):(i-1)),:,left1);
        for xn = 1:length(left1)
            pid = find(~isnan(checkn(:,1,xn)));
            if ~isempty(pid)
                lastp = pid(end);
                fmem(xn,:) = squeeze(checkn(lastp,:,xn));
                fmtime(xn) = tpd-lastp;
            end
        end
        fmtime(isnan(fmtime)) = inf;
        fnid = find(~isnan(fmem(:,1))); fnidreal = left1(fnid);
        fmemr = fmem(fnid,:);
        % check leftovers
        left2sorted = nan(size(left2));
        % populate left2sorted -> sort left2 to match left1 (fewest
        % overlaps) check hpop first, then place
        pd = pdist2(fmem,left2mnew);
        [mm, mmid] = min(pd);
        % if multiple in column, find
        putnan = [];
        for ll = 1:length(mm)
            mmid1 = ll;
            mmid2 = mmid(ll);
            mpdcurrd = mm(ll);
            if mpdcurrd < tpixH
                left2sorted(mmid2) = lmnidreal(mmid1);
                fmtime(mmid2) = -1;
            else
                putnan = [putnan lmnidreal(ll)];
            end
        end
        if ~isempty(putnan)
            numneeded = length(putnan);
            [st, sts] = sort(fmtime,'descend');
            
            if length(sts) >= numneeded
                left2sorted(sts(1:numneeded)) = putnan;
            else
                keyboard
            end
        end
        tins = ~isnan(left2sorted); 
        tins2 = left2sorted(tins);
        tx = find(tins==1); txx = left1(tx);
        ctemp(left1(tins),:) = f2(tins2,:);
    end
    combed(i,:,:) = ctemp';
    if sum(~isnan(combed(i,1,:)))~=Fmn(i)
        fprintf(1,'mismatch')
        keyboard
    end
end

% Graph
imagesc(reshape(combed,[540000 66])')

Fmn = zeros(size(Fmerged));
for i =1:length(Fmerged)
    Fmn(i) = size(Fmerged{i},1);
end
mfmn = unique(Fmn);
templateCell = cell(1,max(Fmn));
for i = mfmn
    templateCell{i} = nchoosek(1:i,3);
end

FM2 = cell(size(Fmerged));
for i = 1:n
    FM2{i} = squeeze(combed(i,:,:))';
end


% find all head points
tic % 10 min
checkidx = 1:20:n;
nd = length(checkidx);
trip = zeros(nd,3); dd = zeros(nd,1); mid = zeros(nd,3); ptsH = nan(nd,3,3);
for ni = 1:nd
    nidx = checkidx(ni);
    if rem(ni,100)==0
        fprintf(1,['Processed points for t = ' num2str(ni) ' of ' num2str(nd) '\n']);
    end
    fi = FM2{nidx};
    ni1 = length(fi);
    v1 = templateCell{ni1};
    dA = zeros(size(v1,1),3); dD = zeros(size(v1,1),1);
    for i = 1:size(v1,1)
        dt1 = pdist2(fi(v1(i,1),:),fi(v1(i,2),:));
        dt2 = pdist2(fi(v1(i,2),:),fi(v1(i,3),:));
        dt3 = pdist2(fi(v1(i,1),:),fi(v1(i,3),:));
        dA(i,:) = sort([dt1 dt2 dt3]);
        dD(i) = sum(abs(dA(i,:)-guessDist));
    end
    [ld di] = min(dD);
    trip(ni,:) = v1(di,:);
    mid(ni,:) = mean(fi(v1(di,:),:));
    ptsH(ni,:,:) = fi(v1(di,:),:);
    dd(ni) = ld;
end
toc



cdd = zeros(n,nMarkers);
cddn = nan(size(combed));
for nm = 1:nMarkers
    nm
    temp = [0; sqrt(sum(diff(combed(:,:,nm)).^2,2))];
    ftemp = ~isnan(squeeze(combed(:,1,nm)));
    cc = bwconncomp(ftemp);
    lc = length(cc.PixelIdxList)
    
    
    
    %cdd(2:end,nm) = temp;
end

x = 49725;
t0 = squeeze(combed(x-1,:,nm))';
t1 = squeeze(combed(x,:,nm))';
t2 = squeeze(combed(x+1,:,nm))';
[t0 t1 t2]

headidm = zeros(n,nMarkers);



i = 49725


% find corresponding contiguous strands
% separate head and other joints
% 

temp = lowpass(t1,20,300);

