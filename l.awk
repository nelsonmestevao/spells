/^```{(.*)include=false(.*)}/{
    if(flag == 0){print "\n"};
    flag = 1 - flag;
    next
}

/^```/{
    if(flag == 1){flag = 0};
    next
}

flag==0{print $0; }
