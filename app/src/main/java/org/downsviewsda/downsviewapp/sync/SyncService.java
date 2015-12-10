package org.downsviewsda.downsviewapp.sync;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.util.Log;

/**
 * Created by Terrence on 9/27/2015.
 */
public class SyncService   extends Service {
    private static final Object sSyncAdapterLock = new Object();
    private static SyncAdapter sDownsviewSyncAdapter = null;

    @Override
    public void onCreate() {
        Log.d("SyncService", "onCreate - DownsviewSyncService");
        synchronized (sSyncAdapterLock) {
            if (sDownsviewSyncAdapter == null) {
                sDownsviewSyncAdapter = new SyncAdapter(getApplicationContext(), true);
            }
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return sDownsviewSyncAdapter.getSyncAdapterBinder();
    }
}