package com.dualmoza.app.ads

import android.app.Activity
import android.content.Context
import android.util.Log
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Manages AdMob rewarded ads for free users.
 */
class AdManager(private val context: Context) {

    companion object {
        private const val TAG = "AdManager"
        // Production rewarded ad unit ID
        private const val REWARDED_AD_UNIT_ID = "ca-app-pub-1116360810482665/6920496448"
    }

    private var rewardedAd: RewardedAd? = null

    private val _isAdLoaded = MutableStateFlow(false)
    val isAdLoaded: StateFlow<Boolean> = _isAdLoaded.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    init {
        initializeAds()
    }

    private fun initializeAds() {
        MobileAds.initialize(context) { initializationStatus ->
            Log.d(TAG, "AdMob initialized: $initializationStatus")
            loadRewardedAd()
        }
    }

    fun loadRewardedAd() {
        if (_isLoading.value || rewardedAd != null) return

        _isLoading.value = true

        val adRequest = AdRequest.Builder().build()

        RewardedAd.load(
            context,
            REWARDED_AD_UNIT_ID,
            adRequest,
            object : RewardedAdLoadCallback() {
                override fun onAdLoaded(ad: RewardedAd) {
                    Log.d(TAG, "Rewarded ad loaded")
                    rewardedAd = ad
                    _isAdLoaded.value = true
                    _isLoading.value = false
                    setupFullScreenCallback()
                }

                override fun onAdFailedToLoad(loadAdError: LoadAdError) {
                    Log.e(TAG, "Rewarded ad failed to load: ${loadAdError.message}")
                    rewardedAd = null
                    _isAdLoaded.value = false
                    _isLoading.value = false
                }
            }
        )
    }

    private fun setupFullScreenCallback() {
        rewardedAd?.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdClicked() {
                Log.d(TAG, "Ad clicked")
            }

            override fun onAdDismissedFullScreenContent() {
                Log.d(TAG, "Ad dismissed")
                rewardedAd = null
                _isAdLoaded.value = false
                // Preload next ad
                loadRewardedAd()
            }

            override fun onAdFailedToShowFullScreenContent(adError: AdError) {
                Log.e(TAG, "Ad failed to show: ${adError.message}")
                rewardedAd = null
                _isAdLoaded.value = false
                loadRewardedAd()
            }

            override fun onAdImpression() {
                Log.d(TAG, "Ad impression recorded")
            }

            override fun onAdShowedFullScreenContent() {
                Log.d(TAG, "Ad showed")
            }
        }
    }

    /**
     * Shows a rewarded ad and calls the callback when the user earns the reward.
     * Returns false if the ad is not ready.
     */
    fun showRewardedAd(activity: Activity, onRewarded: () -> Unit): Boolean {
        val ad = rewardedAd ?: return false

        ad.show(activity) { rewardItem ->
            Log.d(TAG, "User earned reward: ${rewardItem.amount} ${rewardItem.type}")
            onRewarded()
        }

        return true
    }

    /**
     * Check if a rewarded ad is ready to show.
     */
    fun isReady(): Boolean {
        return rewardedAd != null
    }
}
