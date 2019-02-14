/```(.*)?/{
    if(flag == 1){print "\n"};
    flag = 1 - flag;
    next
}
flag==1{print $0; }
