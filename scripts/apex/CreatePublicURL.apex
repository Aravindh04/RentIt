ContentDistribution cd = new ContentDistribution();
cd.Name = 'External Portal View';
cd.ContentVersionId = '068fj00000E9v73AAB'; // Replace with your ContentVersion ID
cd.PreferencesAllowViewInBrowser = true;
cd.PreferencesLinkLatestVersion = true;
cd.PreferencesNotifyOnVisit = false;
cd.PreferencesPasswordRequired = false;
insert cd;


cd = [SELECT DistributionPublicUrl, ContentDownloadUrl FROM ContentDistribution WHERE Id = :cd.Id];
System.debug('PDF Viewer URL: ' + cd.ContentDownloadUrl);
System.debug('PDF Distribution URL: ' + cd.DistributionPublicUrl);

