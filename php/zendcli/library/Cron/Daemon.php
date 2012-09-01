<?php

// Verwendung von Ticks wird seit PHP 4.3.0. benötigt
declare(ticks = 1);

require_once('Zend/Date.php');
require_once('Zend/Locale/Format.php');

require_once('Cron/Tab.php');
require_once('Cron/Job.php');

class Cron_Daemon {
    protected $crontab = null;
    protected $now     = null;
    protected $parallel = null;

    protected $childs = array();

    public function __construct(Cron_Tab $crontab){
        $this->now = Zend_Date::now();
        $this->crontab = $crontab;

        $this->parallel = function_exists('pcntl_fork');
        if($this->parallel){
            // install signal handlers
            //pcntl_signal(SIGCHLD, array($this, 'sighandler'), false);
        }
    }

    public function setNow(Zend_Date $now){
        $this->now = $now;
        return $this;
    }
    public function getNow(){
        return $this->now;
    }

    public function sighandler($signo){
        switch($signo){
            case SIGCHLD:
                $state = 0;
                while(($pid = pcntl_wait($state, WNOHANG))>0){
                    if(!isset($this->childs[$pid])){
                        $this->childs[$pid] = array();
                    }
                    $this->childs[$pid]['state'] = $state;
                }
                break;
        }
    }

    public function getJobsToRun(){
        $jobs = array();
        foreach($this->crontab as $entry){
            if($entry->shallRun($this->now)){
                $jobs[] = $entry->getCronJob();
            }
        }
        return $jobs;
    }

    public function exec(){

        $jobs = $this->getJobsToRun();
        foreach($jobs as $job){
            $this->executeJob($job);
        }
        $this->waitForJobsToFinish();

    }
    protected function executeJob(Cron_Job $job){
        $jobname = $job->getJobName();
        if($this->parallel){
            $pid = pcntl_fork();
            switch($pid){
                case 0:
                    // child
                    $job->run();
                    exit(0);

                    break;
                case -1:
                    trigger_error("could not run '".get_class($job)."': fork returned -1", E_USER_WARNING);
                    break;
                default:
                    // parent

                    // here there could be a race condition
                    // in case the child exit's and signal's the parent
                    // before the following line gets executed
                    if(!isset($this->jobs[$pid])){
                        $this->childs[$pid] = array();
                    }
                    $this->childs[$pid]['job'] = $job;
                    $this->childs[$pid]['start'] = $this->now;

                    break;
            }
        }
        else{
            $job->run();
        }
    }

    protected function waitForJobsToFinish(){
        if($this->parallel){
            while(count($this->childs)>0){
    		    foreach($this->childs as $pid => $jobarr){
    		        $status = null;
    		        if(pcntl_waitpid ( $pid, $status, WNOHANG)>0){
                        //$diff = Zend_Date::now()->get(Zend_Date::TIMESTAMP) - $this->now->get(Zend_Date::TIMESTAMP);
    		            $jobarr['job']->setHasRun(true);
    		            unset($this->childs[$pid]);
    		            continue;
    		        }
    		    }
    		    if(count($this->childs)>0){
    		        usleep(500000);
    		    }
            }
        }
    }
}
