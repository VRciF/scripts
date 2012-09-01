<?php

class CronjobController extends Zend_Controller_Action
{

    protected $cronjobconfig = null;
    protected $_jobs = null;
    protected $locked = null;

    public function init(){}

    public function preDispatch(){
    	$this->cronjobconfig = Zend_Registry::get('crontab');
        $this->cronjobconfig = dirname(__FILE__).'/../Config/crontab';

       	$this->_jobs = explode("\n",file_get_contents($this->cronjobconfig));
    }

    public function indexAction()
    {
        $forcejob = @$_SERVER["argv"][1];
        if(strlen($forcejob)>0){
            $this->_jobs = array(trim("* * * * * $forcejob"));
        }

        $now = Zend_Date::now();

        $crontab = new Cron_Tab();

        foreach($this->_jobs as $line){
        	$line = trim($line);
        	if(strlen($line)<=0){ continue; }
        	$comment = strpos($line, ";");
            if($comment!==false){
        		$line = substr($line, 0, $comment);
        	}
       		$comment = strpos($line, "#");
        	if($comment!==false){
        		$line = substr($line, 0, $comment);
        	}
        	if(strlen($line)<=0){ continue; }

        	$pos = strrpos($line, " ");
        	if($pos===false){
        		$pos = strrpos($line, "\t");
        	}
        	if($pos===false){
        		continue;
        	}
        	$class = trim(substr($line, $pos+1));
        	if(strpos($class, "Cron_Job")===false){
        		$class = "Cron_Job_$class";
        	}
        	$crontabexectime = trim(substr($line, 0,$pos));

            $cronjob = new $class();

	        $reflector = new ReflectionClass(get_class($cronjob));
	        $classfilename = $reflector->getFileName();

	        $lockfp = null;
	        if($cronjob->_singleinstance){
	        	$lockfp = fopen($classfilename,"r");
	        	if(!is_resource($lockfp)){ continue; }
	        	if(!flock($lockfp, LOCK_EX|LOCK_NB)){
	        		continue;
	        	}
	        }

            $crontabentry = new Cron_Tab_Entry(new Cron_Tab_ExecTime($crontabexectime),
                                                     $cronjob);
            $crontabentry->lockfp = $lockfp;
            $crontab->addEntry($crontabentry);

        }

        $daemon = new Cron_Daemon($crontab);
        $jobs = $daemon->setNow($now)
                       ->getJobsToRun();

        // exec jobs
        $daemon->exec();

        $end = Zend_Date::now();

    }

}
